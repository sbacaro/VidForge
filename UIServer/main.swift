import Foundation
import Network

@main
struct VidForgeServerMain {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("-h") || args.contains("--help") {
            print("""
            VidForge UI server

              vidforge-ui-server [--port 8742]

            Opens http://127.0.0.1:<port> in your browser.
            Engines are bundled; nothing else is downloaded.
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

        let server = ForgeHTTPServer(port: port)
        do {
            try await server.start()
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }

        let url = "http://127.0.0.1:\(port)"
        print("VidForge UI → \(url)")
        print("Press Ctrl+C to stop.")
        _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [url])

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
            let probe = try await Shell.runJSON(executable: ToolPaths.ytDlp, arguments: [
                "--no-update", "--ffmpeg-location", ToolPaths.home.path,
                "--dump-single-json", "--no-playlist", "--no-warnings", "--skip-download", job.url
            ])
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
            update(jobID) {
                $0.phase = "failed"
                $0.status = error.localizedDescription
                $0.error = error.localizedDescription
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
        let path = parts.count > 1 ? String(parts[1]) : "/"

        let response: Data
        if method == "GET" && (path == "/" || path.hasPrefix("/?")) {
            response = http(200, "text/html; charset=utf-8", UI.html)
        } else if method == "GET" && path == "/api/jobs" {
            let jobs = await hub.list()
            let data = (try? JSONEncoder().encode(jobs)) ?? Data("[]".utf8)
            response = http(200, "application/json", String(data: data, encoding: .utf8) ?? "[]")
        } else if method == "POST" && path == "/api/forge" {
            struct Req: Codable { var url: String; var alloy: String }
            if let req = try? JSONDecoder().decode(Req.self, from: body), !req.url.isEmpty {
                let job = await hub.enqueue(url: req.url, alloy: req.alloy)
                Task { await hub.pumpIfNeeded() }
                let data = (try? JSONEncoder().encode(job)) ?? Data("{}".utf8)
                response = http(200, "application/json", String(data: data, encoding: .utf8) ?? "{}")
            } else {
                response = http(400, "application/json", #"{"error":"bad request"}"#)
            }
        } else if method == "POST" && path == "/api/reveal" {
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

    private func http(_ code: Int, _ type: String, _ body: String) -> Data {
        let status = code == 200 ? "OK" : (code == 404 ? "Not Found" : "Error")
        let header = "HTTP/1.1 \(code) \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        return Data((header + body).utf8)
    }
}

enum UI {
    static let html = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>VidForge</title>
<style>
  :root {
    --bg0:#12110f; --bg1:#1a1612; --ink:#f4ead7; --muted:rgba(244,234,215,.55);
    --ember:#f08a2a; --ember2:#ffcf70; --line:rgba(255,255,255,.08);
    --ok:#7dcf7a; --bad:#ef6a5a;
  }
  *{box-sizing:border-box}
  body{
    margin:0; min-height:100vh; color:var(--ink);
    font:15px/1.45 "Avenir Next", "Segoe UI", sans-serif;
    background:
      radial-gradient(900px 480px at 50% 115%, rgba(240,80,10,.28), transparent 60%),
      radial-gradient(520px 320px at 10% 20%, rgba(40,90,110,.16), transparent 60%),
      linear-gradient(160deg, var(--bg0), var(--bg1) 50%, #0d0c0b);
  }
  .wrap{max-width:1080px;margin:0 auto;padding:36px 22px 60px}
  h1{
    margin:0; font:800 42px/1 "Avenir Next Condensed","Avenir Next",sans-serif;
    letter-spacing:.18em; text-transform:uppercase;
    background:linear-gradient(90deg,#fff1d2,var(--ember2),var(--ember));
    -webkit-background-clip:text; background-clip:text; color:transparent;
    filter:drop-shadow(0 0 18px rgba(240,100,20,.35));
  }
  .tag{margin-top:8px;color:var(--muted); letter-spacing:.04em}
  .panel{
    margin-top:28px; padding:18px; border:1px solid var(--line);
    background:rgba(255,255,255,.035); border-radius:16px;
    backdrop-filter: blur(8px);
  }
  label{display:block; font-size:11px; letter-spacing:.18em; color:var(--muted); margin-bottom:8px}
  input[type=url], select{
    width:100%; border:1px solid rgba(255,255,255,.12); background:rgba(0,0,0,.28);
    color:var(--ink); border-radius:12px; padding:14px 14px; outline:none;
  }
  input[type=url]:focus{border-color:rgba(240,138,42,.7)}
  .alloys{display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:10px; margin-top:14px}
  .alloy{
    text-align:left; cursor:pointer; border-radius:12px; padding:12px;
    border:1px solid var(--line); background:rgba(255,255,255,.03); color:inherit;
  }
  .alloy.active{border-color:rgba(240,138,42,.8); background:rgba(240,138,42,.1)}
  .alloy b{display:block; margin-bottom:4px}
  .alloy span{color:var(--muted); font-size:12px}
  button.strike{
    margin-top:16px; width:100%; border:0; border-radius:12px; padding:15px 18px;
    font-weight:700; cursor:pointer; color:#1a1208;
    background:linear-gradient(180deg, var(--ember2), var(--ember));
    box-shadow:0 10px 30px rgba(240,100,20,.35);
  }
  button.strike:disabled{opacity:.5; cursor:not-allowed; box-shadow:none}
  .jobs{display:flex; flex-direction:column; gap:10px; margin-top:18px}
  .job{padding:14px; border-radius:12px; border:1px solid var(--line); background:rgba(0,0,0,.22)}
  .job .top{display:flex; justify-content:space-between; gap:12px; align-items:flex-start}
  .job .phase{font-size:10px; letter-spacing:.12em; text-transform:uppercase; color:var(--ember2)}
  .job .phase.done{color:var(--ok)} .job .phase.fail{color:var(--bad)}
  .bar{height:6px; border-radius:999px; background:rgba(255,255,255,.08); margin:10px 0; overflow:hidden}
  .bar > i{display:block; height:100%; width:0; background:linear-gradient(90deg,#d2410a,var(--ember2)); transition:width .25s}
  .status{color:var(--muted); font-size:12px; word-break:break-word}
  .link{color:var(--ember2); cursor:pointer; background:none; border:0; padding:0; font:inherit}
  @media (max-width:720px){ .alloys{grid-template-columns:1fr} h1{font-size:32px; letter-spacing:.12em} }
</style>
</head>
<body>
  <div class="wrap">
    <h1>VidForge</h1>
    <div class="tag">Pull ore from the web. Quench it into lasting metal. · local engines only</div>

    <div class="panel">
      <label>ORE</label>
      <input id="url" type="url" placeholder="Paste a YouTube / Vimeo / other video URL…"/>
      <label style="margin-top:16px">ALLOY</label>
      <div class="alloys" id="alloys"></div>
      <button class="strike" id="strike">Strike the Anvil</button>
    </div>

    <div class="panel">
      <label>THE QUEUE</label>
      <div class="jobs" id="jobs"><div class="status">The anvil is cold.</div></div>
    </div>
  </div>
<script>
const alloys = [
  {id:'archive-pure', title:'Archive Pure', desc:'Maximum fidelity remux → MKV'},
  {id:'crystal', title:'Crystal', desc:'Near-lossless HEVC (x265 CRF 16)'},
  {id:'tempered', title:'Tempered', desc:'High-quality H.264 for playback'},
  {id:'audio-ingot', title:'Audio Ingot', desc:'Best audio → FLAC'},
];
let selected = 'archive-pure';
const box = document.getElementById('alloys');
alloys.forEach(a => {
  const b = document.createElement('button');
  b.type='button'; b.className='alloy'+(a.id===selected?' active':'');
  b.innerHTML = `<b>${a.title}</b><span>${a.desc}</span>`;
  b.onclick=()=>{selected=a.id; [...box.children].forEach(x=>x.classList.remove('active')); b.classList.add('active');};
  box.appendChild(b);
});

async function refresh(){
  const jobs = await (await fetch('/api/jobs')).json();
  const el = document.getElementById('jobs');
  if(!jobs.length){ el.innerHTML='<div class="status">The anvil is cold.</div>'; return; }
  el.innerHTML = jobs.map(j => {
    const cls = j.phase==='finished'?'done':(j.phase==='failed'?'fail':'');
    const reveal = j.output ? `<button class="link" onclick="reveal('${j.output.replace(/'/g,"\\\\'")}')">Reveal</button>` : '';
    return `<div class="job"><div class="top"><div><strong>${escapeHtml(j.title)}</strong><div class="status">${escapeHtml(j.alloy)}</div></div><div class="phase ${cls}">${escapeHtml(j.phase)}</div></div><div class="bar"><i style="width:${Math.round((j.progress||0)*100)}%"></i></div><div class="status">${escapeHtml(j.status||'')}</div>${reveal}</div>`;
  }).join('');
}
function escapeHtml(s){return String(s).replace(/[&<>"']/g,c=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));}
async function reveal(path){ await fetch('/api/reveal',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path})}); }
document.getElementById('strike').onclick = async () => {
  const url = document.getElementById('url').value.trim();
  if(!url) return;
  document.getElementById('strike').disabled = true;
  await fetch('/api/forge',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({url, alloy:selected})});
  document.getElementById('url').value='';
  document.getElementById('strike').disabled = false;
  refresh();
};
refresh(); setInterval(refresh, 1200);
</script>
</body>
</html>
"""#
}
