import Foundation
import Network
import VidForgeCore

@main
struct VidForgeServerMain {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("-h") || args.contains("--help") {
            print("""
            VidForge local companion

              vidforge-ui-server [--port 8742]

            Serves the forge API for the GitHub Pages UI and opens:
            https://sbacaro.github.io/VidForge/

            Uses bundled yt-dlp/ffmpeg plus cookies from your browser
            (auto: chrome → chromium → brave → edge → safari).
            Override with VIDFORGE_BROWSER=chrome|safari|…
            """)
            Foundation.exit(0)
        }

        var port: UInt16 = 8742
        if let idx = args.firstIndex(of: "--port"), idx + 1 < args.count, let p = UInt16(args[idx + 1]) {
            port = p
        }

        do {
            try ToolPaths.requireTools()
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }

        let cookies = await CookieSession.shared.current(
            ytDlp: ToolPaths.ytDlp,
            ffmpegHome: ToolPaths.home.path,
            force: true
        )

        let server = ForgeHTTPServer(port: port)
        do {
            try await server.start()
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }

        let api = "http://127.0.0.1:\(port)"
        let pages = "https://sbacaro.github.io/VidForge/"
        print("VidForge companion API → \(api)")
        print("VidForge UI            → \(pages)")
        if cookies.ok {
            print("Browser cookies        → \(cookies.browser ?? "?")")
        } else {
            fputs("warning: \(cookies.message)\n", stderr)
        }
        print("Press Ctrl+C to stop.")
        _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [pages])

        // Keep alive
        while true {
            try? await Task.sleep(nanoseconds: 3_600_000_000_000)
        }
    }
}

// MARK: - Tools (shared install layout)

enum ToolPaths {
    static var home: URL {
        if let env = ProcessInfo.processInfo.environment["VIDFORGE_HOME"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let local = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/vidforge/bin", isDirectory: true)
        if FileManager.default.fileExists(atPath: local.appendingPathComponent("ffmpeg").path) {
            return local
        }
        let beside = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: beside.appendingPathComponent("ffmpeg").path) {
            return beside
        }
        return local
    }

    static var ytDlp: URL { home.appendingPathComponent("yt-dlp") }
    static var ffmpeg: URL { home.appendingPathComponent("ffmpeg") }

    static func requireTools() throws {
        for (name, url) in [("yt-dlp", ytDlp), ("ffmpeg", ffmpeg)] {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw NSError(domain: "VidForge", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Bundled tool missing: \(name). Re-run Scripts/install-cli.sh"
                ])
            }
        }
    }
}

enum Alloy: String, CaseIterable {
    case archivePure = "archive-pure"
    case crystal = "crystal"
    case tempered = "tempered"
    case audioIngot = "audio-ingot"

    var label: String {
        switch self {
        case .archivePure: return "Archive Pure"
        case .crystal: return "Crystal"
        case .tempered: return "Tempered"
        case .audioIngot: return "Audio Ingot"
        }
    }

    var formatSelector: String {
        self == .audioIngot ? "ba/b" : "bv*+ba/b"
    }
}

// MARK: - Job state

actor JobHub {
    struct Job: Codable {
        var id: String
        var url: String
        var alloy: String
        var title: String
        var phase: String
        var progress: Double
        var status: String
        var output: String?
        var error: String?
    }

    private var jobs: [Job] = []
    private var running = false

    func list() -> [Job] { jobs }

    func enqueue(url: String, alloy: String) -> Job {
        let job = Job(
            id: UUID().uuidString,
            url: url,
            alloy: alloy,
            title: "Unknown ore",
            phase: "queued",
            progress: 0,
            status: "Waiting at the anvil…"
        )
        jobs.insert(job, at: 0)
        return job
    }

    func update(_ id: String, mutate: (inout Job) -> Void) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[i])
    }

    func pumpIfNeeded() async {
        guard !running else { return }
        guard let next = jobs.first(where: { $0.phase == "queued" }) else { return }
        running = true
        defer { running = false }
        await forge(jobID: next.id)
        await pumpIfNeeded()
    }

    private func forge(jobID: String) async {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        let alloy = Alloy(rawValue: job.alloy) ?? .archivePure
        let outDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/VidForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        update(jobID) {
            $0.phase = "prospecting"
            $0.progress = 0.08
            $0.status = "Reading the ore veins…"
        }

        do {
            let cookies = await CookieSession.shared.current(
                ytDlp: ToolPaths.ytDlp,
                ffmpegHome: ToolPaths.home.path
            )
            let cookieArgs = BrowserCookies.arguments(for: cookies)
            if cookies.ok {
                update(jobID) {
                    $0.status = "Reading ore with \(cookies.browser ?? "browser") cookies…"
                }
            } else {
                update(jobID) {
                    $0.status = "Cookie jar weak — trying anyway…"
                }
            }

            var probeArgs = [
                "--no-update", "--ffmpeg-location", ToolPaths.home.path,
                "--dump-single-json", "--no-playlist", "--no-warnings", "--skip-download"
            ]
            probeArgs += cookieArgs
            probeArgs.append(job.url)

            let probe = try await Shell.runJSON(executable: ToolPaths.ytDlp, arguments: probeArgs)
            let title = (probe["title"] as? String) ?? "Untitled"
            update(jobID) {
                $0.title = title
                $0.phase = "smelting"
                $0.progress = 0.2
                $0.status = "Smelting best streams…"
            }

            let safe = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " -")
            let template = outDir.appendingPathComponent("\(safe).%(ext)s").path
            var args = [
                "--no-update", "--ffmpeg-location", ToolPaths.home.path,
                "--no-playlist", "--newline", "--progress",
                "-f", alloy.formatSelector, "-o", template,
                "--print", "after_move:filepath", "--no-mtime", "--no-part"
            ]
            args += cookieArgs
            switch alloy {
            case .archivePure: args += ["--merge-output-format", "mkv", "--remux-video", "mkv"]
            case .crystal, .tempered: args += ["--merge-output-format", "mkv"]
            case .audioIngot: args += ["-x", "--audio-format", "flac", "--audio-quality", "0"]
            }
            args.append(job.url)

            let before = Set((try? FileManager.default.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)) ?? [])
            let stdout = try await Shell.run(executable: ToolPaths.ytDlp, arguments: args) { [jobID] line in
                Task {
                    await self.update(jobID) {
                        $0.status = line
                        if let p = Shell.parseProgress(line) {
                            $0.progress = 0.2 + p * 0.55
                        }
                    }
                }
            }

            var downloaded: URL?
            if let printed = stdout.split(separator: "\n").map(String.init).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty && !$0.hasPrefix("[") }).last,
               FileManager.default.fileExists(atPath: printed) {
                downloaded = URL(fileURLWithPath: printed)
            } else {
                let after = (try? FileManager.default.contentsOfDirectory(at: outDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
                downloaded = after.filter { !before.contains($0) }.max(by: { a, b in
                    let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return da < db
                })
            }
            guard let input = downloaded else {
                throw NSError(domain: "VidForge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Output file not found"])
            }

            update(jobID) {
                $0.phase = "quenching"
                $0.progress = 0.82
                $0.status = "Quenching on the anvil…"
            }

            let forged = try await quench(input: input, alloy: alloy, outputDirectory: outDir, jobID: jobID)
            update(jobID) {
                $0.phase = "finished"
                $0.progress = 1
                $0.status = "Ready"
                $0.output = forged.path
            }
        } catch {
            let message = BrowserCookies.friendlyError(error.localizedDescription)
            update(jobID) {
                $0.phase = "failed"
                $0.status = message
                $0.error = message
            }
        }
    }

    private func quench(input: URL, alloy: Alloy, outputDirectory: URL, jobID: String) async throws -> URL {
        let stem = input.deletingPathExtension().lastPathComponent
        switch alloy {
        case .archivePure:
            let output = outputDirectory.appendingPathComponent("\(stem) — Archive Pure.mkv")
            if input.pathExtension.lowercased() == "mkv" {
                if input.standardizedFileURL != output.standardizedFileURL {
                    if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
                    try FileManager.default.copyItem(at: input, to: output)
                }
                return output
            }
            try await Shell.run(executable: ToolPaths.ffmpeg, arguments: [
                "-y", "-hide_banner", "-i", input.path, "-map", "0", "-c", "copy", output.path
            ]) { _ in }
            return output
        case .crystal:
            let output = outputDirectory.appendingPathComponent("\(stem) — Crystal.mp4")
            try await Shell.run(executable: ToolPaths.ffmpeg, arguments: [
                "-y", "-hide_banner", "-i", input.path, "-map", "0:v:0", "-map", "0:a?",
                "-c:v", "libx265", "-crf", "16", "-preset", "slow", "-tag:v", "hvc1",
                "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k", "-movflags", "+faststart", output.path
            ]) { line in
                Task { await self.update(jobID) { $0.status = line } }
            }
            try? FileManager.default.removeItem(at: input)
            return output
        case .tempered:
            let output = outputDirectory.appendingPathComponent("\(stem) — Tempered.mp4")
            try await Shell.run(executable: ToolPaths.ffmpeg, arguments: [
                "-y", "-hide_banner", "-i", input.path, "-map", "0:v:0", "-map", "0:a?",
                "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-profile:v", "high",
                "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k", "-movflags", "+faststart", output.path
            ]) { line in
                Task { await self.update(jobID) { $0.status = line } }
            }
            try? FileManager.default.removeItem(at: input)
            return output
        case .audioIngot:
            let output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.flac")
            if ["flac", "wav", "m4a", "opus", "mp3"].contains(input.pathExtension.lowercased()) {
                let dest = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.\(input.pathExtension)")
                if input.standardizedFileURL != dest.standardizedFileURL {
                    if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
                    try FileManager.default.copyItem(at: input, to: dest)
                }
                return dest
            }
            try await Shell.run(executable: ToolPaths.ffmpeg, arguments: [
                "-y", "-hide_banner", "-i", input.path, "-vn", "-c:a", "flac", output.path
            ]) { _ in }
            return output
        }
    }
}

enum Shell {
    static func parseProgress(_ line: String) -> Double? {
        guard let r = line.range(of: #"(\d{1,3}(?:\.\d+)?)%"#, options: .regularExpression) else { return nil }
        return Double(line[r].dropLast()).map { $0 / 100 }
    }

    static func run(executable: URL, arguments: [String], onLine: @escaping (String) -> Void) async throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ["PATH": ToolPaths.home.path, "YTDLP_NO_UPDATE": "1"]
        let out = Pipe(); let err = Pipe()
        process.standardOutput = out; process.standardError = err
        var data = Data()
        let lock = NSLock()
        out.fileHandleForReading.readabilityHandler = { h in
            let c = h.availableData; guard !c.isEmpty else { return }
            lock.lock(); data.append(c); lock.unlock()
            if let t = String(data: c, encoding: .utf8) {
                t.split(whereSeparator: \.isNewline).forEach { onLine(String($0)) }
            }
        }
        err.fileHandleForReading.readabilityHandler = { h in
            let c = h.availableData; guard !c.isEmpty else { return }
            lock.lock(); data.append(c); lock.unlock()
            if let t = String(data: c, encoding: .utf8) {
                t.split(whereSeparator: \.isNewline).forEach { onLine(String($0)) }
            }
        }
        try process.run()
        process.waitUntilExit()
        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil
        lock.lock(); let text = String(data: data, encoding: .utf8) ?? ""; lock.unlock()
        if process.terminationStatus != 0 {
            throw NSError(domain: "VidForge", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: text])
        }
        return text
    }

    static func runJSON(executable: URL, arguments: [String]) async throws -> [String: Any] {
        let text = try await run(executable: executable, arguments: arguments) { _ in }
        guard let d = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            throw NSError(domain: "VidForge", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bad metadata JSON"])
        }
        return obj
    }
}

// MARK: - Tiny HTTP server

final class ForgeHTTPServer: @unchecked Sendable {
    let port: UInt16
    let hub = JobHub()
    private var listener: NWListener?

    init(port: UInt16) { self.port = port }

    func start() async throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            final class Once: @unchecked Sendable {
                var done = false
                let lock = NSLock()
                func run(_ body: () -> Void) {
                    lock.lock(); defer { lock.unlock() }
                    guard !done else { return }
                    done = true
                    body()
                }
            }
            let once = Once()
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    once.run { cont.resume() }
                case .failed(let e):
                    once.run { cont.resume(throwing: e) }
                default:
                    break
                }
            }
            listener?.start(queue: .global())
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global())
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let range = buf.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buf.subdata(in: buf.startIndex..<range.lowerBound)
                let header = String(data: headerData, encoding: .utf8) ?? ""
                let contentLength = Self.contentLength(from: header)
                let bodyStart = range.upperBound
                let have = buf.count - bodyStart
                if have >= contentLength {
                    let body = buf.subdata(in: bodyStart..<(bodyStart + contentLength))
                    Task { await self.respond(connection: connection, header: header, body: body) }
                    return
                }
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buf)
        }
    }

    private static func contentLength(from header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                return Int(parts[1]) ?? 0
            }
        }
        return 0
    }

    private func respond(connection: NWConnection, header: String, body: Data) async {
        let first = header.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = first.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : "GET"
        let pathOnly = parts.count > 1 ? String(parts[1]).split(separator: "?").first.map(String.init) ?? "/" : "/"

        let response: Data
        if method == "OPTIONS" {
            response = corsPreflight()
        } else if method == "GET" && pathOnly == "/" {
            response = http(200, "text/html; charset=utf-8", Self.landingHTML)
        } else if method == "GET" && pathOnly == "/api/health" {
            let cookies = await CookieSession.shared.current(
                ytDlp: ToolPaths.ytDlp,
                ffmpegHome: ToolPaths.home.path
            )
            struct Health: Encodable {
                let ok: Bool
                let service: String
                let version: String
                let cookiesBrowser: String?
                let cookiesOk: Bool
                let cookiesMessage: String
            }
            let payload = Health(
                ok: true,
                service: "vidforge-companion",
                version: BrowserCookies.version,
                cookiesBrowser: cookies.browser,
                cookiesOk: cookies.ok,
                cookiesMessage: cookies.message
            )
            let data = (try? JSONEncoder().encode(payload)) ?? Data(#"{"ok":true,"service":"vidforge-companion"}"#.utf8)
            response = http(200, "application/json", String(data: data, encoding: .utf8) ?? #"{"ok":true}"#)
        } else if method == "GET" && pathOnly == "/api/jobs" {
            let jobs = await hub.list()
            let data = (try? JSONEncoder().encode(jobs)) ?? Data("[]".utf8)
            response = http(200, "application/json", String(data: data, encoding: .utf8) ?? "[]")
        } else if method == "POST" && pathOnly == "/api/forge" {
            struct Req: Codable { var url: String; var alloy: String }
            if let req = try? JSONDecoder().decode(Req.self, from: body), !req.url.isEmpty {
                let job = await hub.enqueue(url: req.url, alloy: req.alloy)
                Task { await hub.pumpIfNeeded() }
                let data = (try? JSONEncoder().encode(job)) ?? Data("{}".utf8)
                response = http(200, "application/json", String(data: data, encoding: .utf8) ?? "{}")
            } else {
                response = http(400, "application/json", #"{"error":"bad request"}"#)
            }
        } else if method == "POST" && pathOnly == "/api/reveal" {
            struct Req: Codable { var path: String }
            if let req = try? JSONDecoder().decode(Req.self, from: body) {
                _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-R", req.path])
                response = http(200, "application/json", #"{"ok":true}"#)
            } else {
                response = http(400, "application/json", #"{"error":"bad request"}"#)
            }
        } else {
            response = http(404, "text/plain", "Not found")
        }

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func corsPreflight() -> Data {
        let header = """
        HTTP/1.1 204 No Content\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type, Authorization\r
        Access-Control-Allow-Private-Network: true\r
        Access-Control-Max-Age: 86400\r
        Connection: close\r
        \r
        """
        return Data(header.utf8)
    }

    private func http(_ code: Int, _ type: String, _ body: String) -> Data {
        let status = code == 200 ? "OK" : (code == 404 ? "Not Found" : "Error")
        let header = """
        HTTP/1.1 \(code) \(status)\r
        Content-Type: \(type)\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type, Authorization\r
        Access-Control-Allow-Private-Network: true\r
        Connection: close\r
        \r
        \(body)
        """
        return Data(header.utf8)
    }

    private static let landingHTML = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8"/>
      <meta http-equiv="refresh" content="0; url=https://sbacaro.github.io/VidForge/"/>
      <title>VidForge companion</title>
      <style>
        body{font:16px/1.4 system-ui;background:#100e0c;color:#f4ead7;display:grid;place-items:center;min-height:100vh;margin:0}
        a{color:#ffd27a}
      </style>
    </head>
    <body>
      <p>Companion online. Open the UI: <a href="https://sbacaro.github.io/VidForge/">sbacaro.github.io/VidForge</a></p>
    </body>
    </html>
    """
}
