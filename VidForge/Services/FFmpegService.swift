import Foundation

struct FFmpegService {
    private let runner = ProcessRunner()

    func cancel() async {
        await runner.cancel()
    }

    /// Quenches (re-encodes / remuxes) a downloaded file into the chosen alloy.
    func quench(
        input: URL,
        alloy: AlloyPreset,
        outputDirectory: URL,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        guard let ffmpeg = BinaryLocator.ffmpeg else {
            throw ProcessRunnerError.executableMissing("ffmpeg")
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let stem = input.deletingPathExtension().lastPathComponent
        let output: URL
        var arguments: [String]

        switch alloy {
        case .archivePure:
            // Already max quality from merge; remux to MKV keeping streams intact when possible.
            output = outputDirectory.appendingPathComponent("\(stem) — Archive Pure.mkv")
            if input.pathExtension.lowercased() == "mkv" {
                // Copy beside as archived name when already mkv.
                let dest = output
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: input, to: dest)
                return dest
            }
            arguments = [
                "-y", "-hide_banner", "-i", input.path,
                "-map", "0",
                "-c", "copy",
                destPath(output)
            ]

        case .crystal:
            // Visually lossless-ish HEVC — CRF 16, slow preset, retain audio as AAC high or copy if already good.
            output = outputDirectory.appendingPathComponent("\(stem) — Crystal.mp4")
            arguments = [
                "-y", "-hide_banner", "-i", input.path,
                "-map", "0:v:0", "-map", "0:a?",
                "-c:v", "libx265",
                "-crf", "16",
                "-preset", "slow",
                "-tag:v", "hvc1",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac",
                "-b:a", "320k",
                "-movflags", "+faststart",
                destPath(output)
            ]

        case .tempered:
            output = outputDirectory.appendingPathComponent("\(stem) — Tempered.mp4")
            arguments = [
                "-y", "-hide_banner", "-i", input.path,
                "-map", "0:v:0", "-map", "0:a?",
                "-c:v", "libx264",
                "-crf", "16",
                "-preset", "slow",
                "-profile:v", "high",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac",
                "-b:a", "320k",
                "-movflags", "+faststart",
                destPath(output)
            ]

        case .audioIngot:
            // Prefer keeping FLAC from yt-dlp extract; otherwise remux/copy.
            if ["flac", "wav", "m4a", "opus", "mp3"].contains(input.pathExtension.lowercased()) {
                output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.\(input.pathExtension)")
                if input.path != output.path {
                    if FileManager.default.fileExists(atPath: output.path) {
                        try FileManager.default.removeItem(at: output)
                    }
                    try FileManager.default.copyItem(at: input, to: output)
                }
                return output
            }
            output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.flac")
            arguments = [
                "-y", "-hide_banner", "-i", input.path,
                "-vn",
                "-c:a", "flac",
                destPath(output)
            ]
        }

        _ = try await runner.run(
            executable: ffmpeg,
            arguments: arguments,
            onStdoutLine: onLine,
            onStderrLine: onLine
        )

        // Clean intermediate download if quench produced a different file.
        if input.path != output.path,
           FileManager.default.fileExists(atPath: input.path),
           alloy != .archivePure || input.pathExtension.lowercased() != "mkv" {
            // Keep original download for Archive Pure remux failures safety — only remove when quench clearly produced sibling.
            if alloy == .crystal || alloy == .tempered {
                try? FileManager.default.removeItem(at: input)
            }
        }

        return output
    }

    private func destPath(_ url: URL) -> String {
        url.path
    }
}
