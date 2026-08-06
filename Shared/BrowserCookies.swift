import Foundation

/// Resolves yt-dlp `--cookies-from-browser` using an installed logged-in browser.
public enum BrowserCookies {
    public static let version = "1.1.0"

    /// Auto-detect order when `VIDFORGE_BROWSER` is unset.
    public static let candidates = ["chrome", "chromium", "brave", "edge", "safari"]

    public struct Status: Sendable, Equatable {
        public var browser: String?
        public var ok: Bool
        public var message: String

        public init(browser: String?, ok: Bool, message: String) {
            self.browser = browser
            self.ok = ok
            self.message = message
        }
    }

    /// Arguments to append to yt-dlp when a browser jar is available.
    public static func arguments(for status: Status) -> [String] {
        guard let browser = status.browser, !browser.isEmpty else { return [] }
        return ["--cookies-from-browser", browser]
    }

    /// Detect a usable browser cookie jar. Honors `VIDFORGE_BROWSER` override.
    public static func detect(ytDlp: URL, ffmpegHome: String) -> Status {
        if let forced = ProcessInfo.processInfo.environment["VIDFORGE_BROWSER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !forced.isEmpty {
            if probe(browser: forced, ytDlp: ytDlp, ffmpegHome: ffmpegHome) {
                return Status(
                    browser: forced,
                    ok: true,
                    message: "Using \(forced) cookies"
                )
            }
            return Status(
                browser: forced,
                ok: false,
                message: cookieFailureHint(browser: forced)
            )
        }

        for browser in candidates {
            if probe(browser: browser, ytDlp: ytDlp, ffmpegHome: ffmpegHome) {
                return Status(
                    browser: browser,
                    ok: true,
                    message: "Using \(browser) cookies"
                )
            }
        }

        return Status(
            browser: nil,
            ok: false,
            message: cookieFailureHint(browser: nil)
        )
    }

    public static func friendlyError(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("could not copy")
            || lower.contains("failed to decrypt")
            || lower.contains("keychain")
            || lower.contains("permission")
            || lower.contains("operation not permitted")
            || lower.contains("could not find chrome cookies")
            || lower.contains("could not find safari cookies") {
            return cookieFailureHint(browser: nil)
        }
        if lower.contains("sign in to confirm") || lower.contains("not a bot") {
            return "YouTube blocked anonymous access. Stay logged into YouTube in Chrome/Safari, grant Full Disk Access to Terminal (or vidforge-ui), then restart the companion."
        }
        let first = raw.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? raw
        return first.count > 280 ? String(first.prefix(277)) + "…" : first
    }

    private static func cookieFailureHint(browser: String?) -> String {
        let name = browser ?? "your browser"
        return "Could not read \(name) cookies. Log into YouTube in Chrome (preferred) or Safari, then grant Full Disk Access to Terminal / vidforge-ui under System Settings → Privacy & Security, and restart. Override with VIDFORGE_BROWSER=chrome|safari|…"
    }

    /// Cheap jar check: ask yt-dlp to open cookies and print a video id (needs network).
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
        process.environment = [
            "PATH": ffmpegHome,
            "YTDLP_NO_UPDATE": "1"
        ]
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

/// Cached cookie detection shared by the companion HTTP server.
public actor CookieSession {
    public static let shared = CookieSession()

    private var status: BrowserCookies.Status?
    private var checkedAt: Date?
    private let ttl: TimeInterval = 300

    public init() {}

    public func current(ytDlp: URL, ffmpegHome: String, force: Bool = false) -> BrowserCookies.Status {
        if !force,
           let status,
           let checkedAt,
           Date().timeIntervalSince(checkedAt) < ttl,
           status.ok {
            return status
        }
        let next = BrowserCookies.detect(ytDlp: ytDlp, ffmpegHome: ffmpegHome)
        self.status = next
        self.checkedAt = Date()
        return next
    }
}
