import Foundation

struct YtDlpService {
    private let runner = ProcessRunner()

    /// Always prefer bundled ffmpeg; never self-update yt-dlp from the network.
    private var baseArguments: [String] {
        [
            "--no-update",
            "--ffmpeg-location", BinaryLocator.helpersDirectory.path
        ]
    }

    func cancel() async {
        await runner.cancel()
    }

    func probe(url: String) async throws -> MediaProbe {
        guard let bin = BinaryLocator.ytDlp else {
            throw ProcessRunnerError.executableMissing("yt-dlp")
        }

        let output = try await runner.run(
            executable: bin,
            arguments: baseArguments + [
                "--dump-single-json",
                "--no-playlist",
                "--no-warnings",
                "--skip-download",
                url
            ]
        )

        guard let data = output.stdout.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ProcessRunnerError.nonZeroExit(code: 1, stderr: "Could not parse media metadata.")
        }

        let title = (json["title"] as? String) ?? "Untitled"
        let uploader = json["uploader"] as? String
        let duration = json["duration"] as? Double
        let webpage = json["webpage_url"] as? String
        let thumbnail = json["thumbnail"] as? String

        var bestResolution: String?
        if let width = json["width"] as? Int, let height = json["height"] as? Int {
            bestResolution = "\(width)×\(height)"
        } else if let formats = json["formats"] as? [[String: Any]] {
            let ranked = formats.compactMap { format -> (Int, String)? in
                guard let h = format["height"] as? Int else { return nil }
                let w = format["width"] as? Int ?? 0
                return (h, "\(w)×\(h)")
            }.sorted { $0.0 > $1.0 }
            bestResolution = ranked.first?.1
        }

        var formatsSummary: String?
        if let formats = json["formats"] as? [[String: Any]] {
            let heights = Set(formats.compactMap { $0["height"] as? Int }).sorted(by: >)
            if !heights.isEmpty {
                formatsSummary = heights.prefix(6).map { "\($0)p" }.joined(separator: " · ")
            }
        }

        return MediaProbe(
            title: title,
            uploader: uploader,
            duration: duration,
            webpageURL: webpage,
            thumbnail: thumbnail,
            formatsSummary: formatsSummary,
            bestResolution: bestResolution
        )
    }

    /// Downloads with maximum quality streams; bundled ffmpeg merges when needed.
    func download(
        url: String,
        alloy: AlloyPreset,
        outputDirectory: URL,
        preferredFilename: String?,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        guard let bin = BinaryLocator.ytDlp else {
            throw ProcessRunnerError.executableMissing("yt-dlp")
        }
        guard BinaryLocator.ffmpeg != nil else {
            throw ProcessRunnerError.executableMissing("ffmpeg")
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let template: String
        if let preferredFilename, !preferredFilename.isEmpty {
            let safe = preferredFilename
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: " -")
            template = outputDirectory.appendingPathComponent("\(safe).%(ext)s").path
        } else {
            template = outputDirectory.appendingPathComponent("%(title).200B [%(id)s].%(ext)s").path
        }

        var arguments = baseArguments + [
            "--no-playlist",
            "--newline",
            "--progress",
            "-f", alloy.formatSelector,
            "-o", template,
            "--print", "after_move:filepath",
            "--no-mtime",
            "--no-part"
        ]

        switch alloy {
        case .archivePure:
            // Best A/V streams, remux to MKV without re-encoding.
            arguments += ["--merge-output-format", "mkv", "--remux-video", "mkv"]
        case .crystal, .tempered:
            arguments += ["--merge-output-format", "mkv"]
        case .audioIngot:
            arguments += [
                "-x",
                "--audio-format", "flac",
                "--audio-quality", "0"
            ]
        }

        arguments.append(url)

        let before = Set((try? FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])

        let output = try await runner.run(
            executable: bin,
            arguments: arguments,
            currentDirectory: outputDirectory,
            onStdoutLine: onLine,
            onStderrLine: onLine
        )

        // Prefer printed filepath from yt-dlp.
        let printed = output.stdout
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
            .last

        if let printed, FileManager.default.fileExists(atPath: printed) {
            return URL(fileURLWithPath: printed)
        }

        // Fallback: newest file not present before.
        let after = (try? FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let newcomers = after.filter { !before.contains($0) }
        if let newest = newcomers.max(by: { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }) {
            return newest
        }

        throw ProcessRunnerError.nonZeroExit(code: 1, stderr: "Download finished but output file was not found.")
    }
}
