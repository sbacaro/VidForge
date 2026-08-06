import Foundation

enum ToolPaths {
    /// Prefer tools inside the .app bundle, then VIDFORGE_HOME, then repo vendor/, then ~/.local/share/vidforge/bin.
    static var home: URL {
        if let resource = Bundle.main.resourceURL?
            .appendingPathComponent("engines", isDirectory: true),
           FileManager.default.fileExists(atPath: resource.appendingPathComponent("ffmpeg").path) {
            return resource
        }

        if let env = ProcessInfo.processInfo.environment["VIDFORGE_HOME"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }

        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            .deletingLastPathComponent()
        let beside = exe.appendingPathComponent("engines", isDirectory: true)
        if FileManager.default.fileExists(atPath: beside.appendingPathComponent("ffmpeg").path) {
            return beside
        }

        // Development: .build/.../VidForge → walk up to repo vendor/
        var cursor = exe
        for _ in 0..<6 {
            let vendor = cursor.appendingPathComponent("vendor", isDirectory: true)
            if FileManager.default.fileExists(atPath: vendor.appendingPathComponent("ffmpeg").path) {
                return vendor
            }
            cursor = cursor.deletingLastPathComponent()
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/vidforge/bin", isDirectory: true)
    }

    static var ytDlp: URL { home.appendingPathComponent("yt-dlp") }
    static var ffmpeg: URL { home.appendingPathComponent("ffmpeg") }
    static var ffprobe: URL { home.appendingPathComponent("ffprobe") }

    static func requireTools() throws {
        for (name, url) in [("yt-dlp", ytDlp), ("ffmpeg", ffmpeg), ("ffprobe", ffprobe)] {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ForgeError.missingTool(name)
            }
        }
    }
}

enum ForgeError: LocalizedError {
    case missingTool(String)
    case badMetadata
    case missingOutput
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingTool(let name):
            return "Bundled tool missing: \(name). Run Scripts/vendor-tools.sh then Scripts/install-app.sh."
        case .badMetadata:
            return "Could not read media metadata."
        case .missingOutput:
            return "Download finished but the output file was not found."
        case .processFailed(let message):
            return message
        }
    }
}
