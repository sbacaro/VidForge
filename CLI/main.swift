import Foundation

@main
struct VidForgeCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty || args.contains("-h") || args.contains("--help") {
            print(helpText)
            Foundation.exit(args.isEmpty ? 1 : 0)
        }

        if args.contains("--version") || args.contains("-V") {
            print("VidForge \(version) (bundled yt-dlp + ffmpeg)")
            Foundation.exit(0)
        }

        do {
            let options = try Options.parse(args)
            let engine = ForgeCLIEngine()
            try await engine.run(options: options)
        } catch let error as CLIError {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    static let version = "1.0.0"

    static var helpText: String {
        """
        VidForge — forge web video into lasting local files.

        USAGE:
          vidforge <url> [options]
          vidforge --list-alloys

        OPTIONS:
          -a, --alloy <name>     archive-pure | crystal | tempered | audio-ingot
                                 (default: archive-pure)
          -o, --output <dir>     Output folder (default: ~/Movies/VidForge)
          -h, --help             Show help
          -V, --version          Show version

        EXAMPLES:
          vidforge "https://www.youtube.com/watch?v=…"
          vidforge "https://…" --alloy crystal
          vidforge "https://…" -a audio-ingot -o ~/Desktop/Forged

        Bundled engines live next to this binary (no Homebrew).
        """
    }
}

enum CLIError: LocalizedError {
    case missingURL
    case unknownAlloy(String)
    case missingTool(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Provide a video URL."
        case .unknownAlloy(let name):
            return "Unknown alloy '\(name)'. Use --list-alloys."
        case .missingTool(let name):
            return "Bundled tool missing: \(name). Re-run Scripts/install-cli.sh"
        case .processFailed(let message):
            return message
        }
    }
}

struct Options {
    var url: String
    var alloy: Alloy
    var outputDirectory: URL

    static func parse(_ args: [String]) throws -> Options {
        if args.contains("--list-alloys") {
            for alloy in Alloy.allCases {
                print("\(alloy.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0))  \(alloy.summary)")
            }
            Foundation.exit(0)
        }

        var url: String?
        var alloy = Alloy.archivePure
        var output = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/VidForge", isDirectory: true)

        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-a", "--alloy":
                i += 1
                guard i < args.count else { throw CLIError.unknownAlloy("") }
                guard let parsed = Alloy(rawValue: args[i]) else {
                    throw CLIError.unknownAlloy(args[i])
                }
                alloy = parsed
            case "-o", "--output":
                i += 1
                guard i < args.count else { throw CLIError.missingURL }
                output = URL(fileURLWithPath: (args[i] as NSString).expandingTildeInPath, isDirectory: true)
            case let value where !value.hasPrefix("-"):
                url = value
            default:
                throw CLIError.processFailed("Unknown option: \(arg)")
            }
            i += 1
        }

        guard let url, !url.isEmpty else { throw CLIError.missingURL }
        return Options(url: url, alloy: alloy, outputDirectory: output)
    }
}

enum Alloy: String, CaseIterable {
    case archivePure = "archive-pure"
    case crystal = "crystal"
    case tempered = "tempered"
    case audioIngot = "audio-ingot"

    var summary: String {
        switch self {
        case .archivePure: return "Max fidelity remux → MKV"
        case .crystal: return "Near-lossless HEVC (x265 CRF 16)"
        case .tempered: return "High-quality H.264 (x264 CRF 16)"
        case .audioIngot: return "Best audio → FLAC"
        }
    }

    var formatSelector: String {
        switch self {
        case .audioIngot: return "ba/b"
        default: return "bv*+ba/b"
        }
    }
}

enum ToolPaths {
    /// Prefer VIDFORGE_HOME, then directory next to the executable, then repo vendor/.
    static var home: URL {
        if let env = ProcessInfo.processInfo.environment["VIDFORGE_HOME"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }

        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let beside = exe.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: beside.appendingPathComponent("ffmpeg").path) {
            return beside
        }

        // Development fallback: repo layout
        let repoTools = beside
            .deletingLastPathComponent() // .build/…
            .appendingPathComponent("vendor")
        if FileManager.default.fileExists(atPath: repoTools.appendingPathComponent("ffmpeg").path) {
            return repoTools
        }

        // install layout: ~/.local/share/vidforge/bin
        let local = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/vidforge/bin", isDirectory: true)
        return local
    }

    static var ytDlp: URL { home.appendingPathComponent("yt-dlp") }
    static var ffmpeg: URL { home.appendingPathComponent("ffmpeg") }
    static var ffprobe: URL { home.appendingPathComponent("ffprobe") }

    static func requireTools() throws {
        for (name, url) in [("yt-dlp", ytDlp), ("ffmpeg", ffmpeg), ("ffprobe", ffprobe)] {
            guard FileManager.default.isExecutableFile(atPath: url.path)
                    || FileManager.default.fileExists(atPath: url.path) else {
                throw CLIError.missingTool(name)
            }
        }
    }
}

struct ForgeCLIEngine {
    func run(options: Options) async throws {
        try ToolPaths.requireTools()
        try FileManager.default.createDirectory(at: options.outputDirectory, withIntermediateDirectories: true)

        print("╔══════════════════════════════════════╗")
        print("║           V I D F O R G E            ║")
        print("╚══════════════════════════════════════╝")
        print("Ore:    \(options.url)")
        print("Alloy:  \(options.alloy.rawValue)")
        print("Output: \(options.outputDirectory.path)")
        print("")

        print("→ Prospecting…")
        let probe = try await probe(url: options.url)
        print("  Title:      \(probe.title)")
        if let res = probe.resolution { print("  Resolution: \(res)") }
        if let dur = probe.durationLabel { print("  Duration:   \(dur)") }
        print("")

        print("→ Smelting best streams…")
        let downloaded = try await download(
            url: options.url,
            alloy: options.alloy,
            title: probe.title,
            outputDirectory: options.outputDirectory
        )
        print("  Smelted: \(downloaded.lastPathComponent)")
        print("")

        print("→ Quenching…")
        let forged = try await quench(
            input: downloaded,
            alloy: options.alloy,
            outputDirectory: options.outputDirectory
        )

        print("")
        print("✦ Forged: \(forged.path)")
    }

    private struct Probe {
        var title: String
        var resolution: String?
        var durationLabel: String?
    }

    private func probe(url: String) async throws -> Probe {
        let output = try await runProcess(
            executable: ToolPaths.ytDlp,
            arguments: [
                "--no-update",
                "--ffmpeg-location", ToolPaths.home.path,
                "--dump-single-json",
                "--no-playlist",
                "--no-warnings",
                "--skip-download",
                url
            ]
        )

        guard let data = output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw CLIError.processFailed("Could not parse media metadata.")
        }

        let title = (json["title"] as? String) ?? "Untitled"
        var resolution: String?
        if let w = json["width"] as? Int, let h = json["height"] as? Int {
            resolution = "\(w)×\(h)"
        }
        var durationLabel: String?
        if let duration = json["duration"] as? Double {
            let total = Int(duration.rounded())
            let m = total / 60
            let s = total % 60
            durationLabel = String(format: "%d:%02d", m, s)
        }
        return Probe(title: title, resolution: resolution, durationLabel: durationLabel)
    }

    private func download(url: String, alloy: Alloy, title: String, outputDirectory: URL) async throws -> URL {
        let safe = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: " -")
        let template = outputDirectory.appendingPathComponent("\(safe).%(ext)s").path

        var args = [
            "--no-update",
            "--ffmpeg-location", ToolPaths.home.path,
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
            args += ["--merge-output-format", "mkv", "--remux-video", "mkv"]
        case .crystal, .tempered:
            args += ["--merge-output-format", "mkv"]
        case .audioIngot:
            args += ["-x", "--audio-format", "flac", "--audio-quality", "0"]
        }
        args.append(url)

        let before = Set(contents(of: outputDirectory))
        let stdout = try await runProcess(
            executable: ToolPaths.ytDlp,
            arguments: args,
            echo: true
        )

        if let printed = stdout
            .split(separator: "\n")
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty && !$0.hasPrefix("[") })
            .last,
           FileManager.default.fileExists(atPath: printed) {
            return URL(fileURLWithPath: printed)
        }

        let newcomers = contents(of: outputDirectory).filter { !before.contains($0) }
        if let newest = newcomers.max(by: { a, b in
            modDate(a) < modDate(b)
        }) {
            return newest
        }

        throw CLIError.processFailed("Download finished but output file was not found.")
    }

    private func quench(input: URL, alloy: Alloy, outputDirectory: URL) async throws -> URL {
        let stem = input.deletingPathExtension().lastPathComponent

        switch alloy {
        case .archivePure:
            let output = outputDirectory.appendingPathComponent("\(stem) — Archive Pure.mkv")
            if input.pathExtension.lowercased() == "mkv" {
                if input.standardizedFileURL != output.standardizedFileURL {
                    if FileManager.default.fileExists(atPath: output.path) {
                        try FileManager.default.removeItem(at: output)
                    }
                    try FileManager.default.copyItem(at: input, to: output)
                }
                return output
            }
            try await runProcess(
                executable: ToolPaths.ffmpeg,
                arguments: ["-y", "-hide_banner", "-i", input.path, "-map", "0", "-c", "copy", output.path],
                echo: true
            )
            return output

        case .crystal:
            let output = outputDirectory.appendingPathComponent("\(stem) — Crystal.mp4")
            try await runProcess(
                executable: ToolPaths.ffmpeg,
                arguments: [
                    "-y", "-hide_banner", "-i", input.path,
                    "-map", "0:v:0", "-map", "0:a?",
                    "-c:v", "libx265", "-crf", "16", "-preset", "slow", "-tag:v", "hvc1",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "320k",
                    "-movflags", "+faststart",
                    output.path
                ],
                echo: true
            )
            try? FileManager.default.removeItem(at: input)
            return output

        case .tempered:
            let output = outputDirectory.appendingPathComponent("\(stem) — Tempered.mp4")
            try await runProcess(
                executable: ToolPaths.ffmpeg,
                arguments: [
                    "-y", "-hide_banner", "-i", input.path,
                    "-map", "0:v:0", "-map", "0:a?",
                    "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-profile:v", "high",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "320k",
                    "-movflags", "+faststart",
                    output.path
                ],
                echo: true
            )
            try? FileManager.default.removeItem(at: input)
            return output

        case .audioIngot:
            if ["flac", "wav", "m4a", "opus", "mp3"].contains(input.pathExtension.lowercased()) {
                let output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.\(input.pathExtension)")
                if input.standardizedFileURL != output.standardizedFileURL {
                    if FileManager.default.fileExists(atPath: output.path) {
                        try FileManager.default.removeItem(at: output)
                    }
                    try FileManager.default.copyItem(at: input, to: output)
                }
                return output
            }
            let output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.flac")
            try await runProcess(
                executable: ToolPaths.ffmpeg,
                arguments: ["-y", "-hide_banner", "-i", input.path, "-vn", "-c:a", "flac", output.path],
                echo: true
            )
            return output
        }
    }

    @discardableResult
    private func runProcess(executable: URL, arguments: [String], echo: Bool = false) async throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = [
            "PATH": ToolPaths.home.path,
            "YTDLP_NO_UPDATE": "1"
        ]

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        try process.run()

        var collected = Data()
        let lock = NSLock()

        out.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock(); collected.append(chunk); lock.unlock()
            if echo, let text = String(data: chunk, encoding: .utf8) {
                fputs(text, stdout)
                fflush(stdout)
            }
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock(); collected.append(chunk); lock.unlock()
            if echo, let text = String(data: chunk, encoding: .utf8) {
                fputs(text, stderr)
                fflush(stderr)
            }
        }

        process.waitUntilExit()
        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil

        lock.lock()
        let text = String(data: collected, encoding: .utf8) ?? ""
        lock.unlock()

        if process.terminationStatus != 0 {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CLIError.processFailed(trimmed.isEmpty ? "Process failed (\(process.terminationStatus))" : trimmed)
        }
        return text
    }

    private func contents(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    }

    private func modDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
