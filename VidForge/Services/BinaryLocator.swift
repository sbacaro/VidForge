import Foundation

/// Resolves tools shipped inside VidForge.app — never Homebrew / system PATH.
enum BinaryLocator {
    /// `VidForge.app/Contents/Helpers` (or VIDFORGE_HOME / CLI install path).
    static var helpersDirectory: URL {
        if let env = ProcessInfo.processInfo.environment["VIDFORGE_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }

        let bundle = Bundle.main.bundleURL
        let helpers = bundle
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)

        if FileManager.default.fileExists(atPath: helpers.appendingPathComponent("ffmpeg").path) {
            return helpers
        }

        // Bundle.main for a packaged .app often *is* …/VidForge.app
        let adjacent = bundle.appendingPathComponent("Contents/Helpers", isDirectory: true)
        if FileManager.default.fileExists(atPath: adjacent.appendingPathComponent("ffmpeg").path) {
            return adjacent
        }

        let local = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/vidforge/bin", isDirectory: true)
        if FileManager.default.fileExists(atPath: local.appendingPathComponent("ffmpeg").path) {
            return local
        }

        return helpers
    }

    static var ytDlp: URL? { bundledExecutable(named: "yt-dlp") }
    static var ffmpeg: URL? { bundledExecutable(named: "ffmpeg") }
    static var ffprobe: URL? { bundledExecutable(named: "ffprobe") }

    static var missingToolsMessage: String? {
        var missing: [String] = []
        if ytDlp == nil { missing.append("yt-dlp") }
        if ffmpeg == nil { missing.append("ffmpeg") }
        if ffprobe == nil { missing.append("ffprobe") }
        guard !missing.isEmpty else { return nil }
        return "This VidForge build is incomplete (missing: \(missing.joined(separator: ", "))). Reinstall the app."
    }

    private static func bundledExecutable(named name: String) -> URL? {
        let url = helpersDirectory.appendingPathComponent(name)
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            // Also accept non-marked +x files that still exist (Gatekeeper quirks).
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
        return url
    }
}
