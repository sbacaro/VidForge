import Foundation

/// Orchestrates prospecting → smelting (download) → quenching (encode).
actor ForgeEngine {
    private let yt = YtDlpService()
    private let ffmpeg = FFmpegService()
    private var activeJobID: UUID?

    func cancel() async {
        await yt.cancel()
        await ffmpeg.cancel()
        activeJobID = nil
    }

    func forge(
        jobID: UUID,
        url: String,
        alloy: AlloyPreset,
        outputDirectory: URL,
        onUpdate: @escaping @Sendable (_ title: String?, _ phase: JobPhase, _ progress: Double, _ status: String, _ resolution: String?, _ duration: String?) -> Void,
        onFinished: @escaping @Sendable (Result<URL, Error>) -> Void
    ) async {
        activeJobID = jobID

        do {
            onUpdate(nil, .prospecting, 0.05, "Reading the ore veins…", nil, nil)
            let probe = try await yt.probe(url: url)
            onUpdate(
                probe.title,
                .prospecting,
                0.12,
                "Found: \(probe.title)",
                probe.bestResolution,
                probe.durationLabel
            )

            try Task.checkCancellation()

            onUpdate(probe.title, .smelting, 0.18, "Smelting best streams…", probe.bestResolution, probe.durationLabel)

            let downloaded = try await yt.download(
                url: url,
                alloy: alloy,
                outputDirectory: outputDirectory,
                preferredFilename: probe.title,
                onLine: { line in
                    let progress = Self.parseProgress(from: line) ?? 0.2
                    let mapped = 0.18 + min(max(progress, 0), 1) * 0.55
                    onUpdate(probe.title, .smelting, mapped, line, probe.bestResolution, probe.durationLabel)
                }
            )

            try Task.checkCancellation()

            onUpdate(probe.title, .quenching, 0.78, "Quenching on the anvil…", probe.bestResolution, probe.durationLabel)

            let finished = try await ffmpeg.quench(
                input: downloaded,
                alloy: alloy,
                outputDirectory: outputDirectory,
                onLine: { line in
                    onUpdate(probe.title, .quenching, 0.85, line, probe.bestResolution, probe.durationLabel)
                }
            )

            onUpdate(probe.title, .finished, 1.0, "Ready — \(finished.lastPathComponent)", probe.bestResolution, probe.durationLabel)
            onFinished(.success(finished))
        } catch is CancellationError {
            onUpdate(nil, .cancelled, 0, "Abandoned at the forge.", nil, nil)
            onFinished(.failure(ProcessRunnerError.cancelled))
        } catch let error as ProcessRunnerError {
            if case .cancelled = error {
                onUpdate(nil, .cancelled, 0, "Abandoned at the forge.", nil, nil)
            } else {
                onUpdate(nil, .failed, 0, error.localizedDescription, nil, nil)
            }
            onFinished(.failure(error))
        } catch {
            onUpdate(nil, .failed, 0, error.localizedDescription, nil, nil)
            onFinished(.failure(error))
        }

        activeJobID = nil
    }

    private static func parseProgress(from line: String) -> Double? {
        // yt-dlp: [download]  45.2% of ...
        guard let range = line.range(of: #"(\d{1,3}(?:\.\d+)?)%"#, options: .regularExpression) else {
            return nil
        }
        let token = String(line[range]).replacingOccurrences(of: "%", with: "")
        guard let value = Double(token) else { return nil }
        return value / 100.0
    }
}
