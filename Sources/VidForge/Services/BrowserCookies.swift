import Foundation

enum BrowserCookies: Sendable {
    static let candidates = ["chrome", "chromium", "brave", "edge", "safari"]

    struct Status: Sendable, Equatable {
        var browser: String?
        var ok: Bool
        var message: String

        static let unknown = Status(
            browser: nil,
            ok: false,
            message: "Checking browser cookies…"
        )

        var browserLabel: String {
            guard let browser else { return "browser" }
            return browser.prefix(1).uppercased() + browser.dropFirst()
        }
    }

    static func arguments(for status: Status) -> [String] {
        guard let browser = status.browser, !browser.isEmpty else { return [] }
        return ["--cookies-from-browser", browser]
    }

    static func detect(ytDlp: URL, ffmpegHome: String, preferred: String = "auto") -> Status {
        let forced: String?
        if let env = ProcessInfo.processInfo.environment["VIDFORGE_BROWSER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !env.isEmpty, env != "auto" {
            forced = env
        } else if preferred != "auto" {
            forced = preferred.lowercased()
        } else {
            forced = nil
        }

        if let forced {
            if probe(browser: forced, ytDlp: ytDlp, ffmpegHome: ffmpegHome) {
                return Status(browser: forced, ok: true, message: "Using \(forced) cookies")
            }
            return Status(browser: forced, ok: false, message: failureHint(browser: forced))
        }

        for browser in candidates {
            if probe(browser: browser, ytDlp: ytDlp, ffmpegHome: ffmpegHome) {
                return Status(browser: browser, ok: true, message: "Using \(browser) cookies")
            }
        }

        return Status(browser: nil, ok: false, message: failureHint(browser: nil))
    }

    static func friendlyError(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("could not copy")
            || lower.contains("failed to decrypt")
            || lower.contains("keychain")
            || lower.contains("permission")
            || lower.contains("operation not permitted")
            || lower.contains("could not find") && lower.contains("cookies") {
            return failureHint(browser: nil)
        }
        if lower.contains("sign in to confirm") || lower.contains("not a bot") {
            return "YouTube blocked anonymous access. Stay logged into YouTube in Chrome/Safari, then grant Full Disk Access to VidForge under System Settings → Privacy & Security."
        }
        let first = raw.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? raw
        return first.count > 280 ? String(first.prefix(277)) + "…" : first
    }

    private static func failureHint(browser: String?) -> String {
        let name = browser ?? "your browser"
        return "Could not read \(name) cookies. Log into YouTube in Chrome (preferred), grant Full Disk Access to VidForge, and retry. Settings can force a browser."
    }

    private static func probe(browser: String, ytDlp: URL, ffmpegHome: String) -> Bool {
        let process = Process()
        process.executableURL = ytDlp
        process.arguments = [
            "--no-update",
            "--ffmpeg-location", ffmpegHome,
            "--cookies-from-browser", browser,
            "--skip-download",
            "--no-playlist",
            "--no-warnings",
            "--print", "id",
            "https://www.youtube.com/watch?v=jNQXAC9IVRw"
        ]
        process.environment = ["PATH": ffmpegHome, "YTDLP_NO_UPDATE": "1"]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        return process.terminationStatus == 0
    }
}
