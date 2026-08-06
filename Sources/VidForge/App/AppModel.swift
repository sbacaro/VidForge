import AppKit
import Foundation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    var urlText: String = ""
    var selectedAlloy: Alloy = .archivePure
    var jobs: [ForgeJob] = []
    var busy = false
    var statusMessage: String = "Heating the forge…"
    var cookiesStatus: BrowserCookies.Status = .unknown
    var preferredBrowser: String = UserDefaults.standard.string(forKey: "preferredBrowser") ?? "auto" {
        didSet { UserDefaults.standard.set(preferredBrowser, forKey: "preferredBrowser") }
    }
    var outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/VidForge", isDirectory: true)

    private let engine = ForgeEngine()

    init() {
        Task { await refreshEnvironment() }
    }

    func refreshEnvironment() async {
        do {
            try ToolPaths.requireTools()
            cookiesStatus = await Task.detached(priority: .utility) {
                BrowserCookies.detect(
                    ytDlp: ToolPaths.ytDlp,
                    ffmpegHome: ToolPaths.home.path,
                    preferred: UserDefaults.standard.string(forKey: "preferredBrowser") ?? "auto"
                )
            }.value
            if cookiesStatus.ok {
                statusMessage = "Forge ready · \(cookiesStatus.browserLabel) cookies"
            } else {
                statusMessage = cookiesStatus.message
            }
        } catch {
            statusMessage = error.localizedDescription
            cookiesStatus = .unknown
        }
    }

    func strike() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !busy else { return }

        let job = ForgeJob(url: url, alloy: selectedAlloy)
        jobs.insert(job, at: 0)
        urlText = ""
        busy = true

        Task {
            defer { busy = false }
            do {
                try ToolPaths.requireTools()
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                let cookies = await Task.detached(priority: .utility) {
                    BrowserCookies.detect(
                        ytDlp: ToolPaths.ytDlp,
                        ffmpegHome: ToolPaths.home.path,
                        preferred: UserDefaults.standard.string(forKey: "preferredBrowser") ?? "auto"
                    )
                }.value
                cookiesStatus = cookies

                try await engine.forge(
                    job: job,
                    outputDirectory: outputDirectory,
                    cookies: cookies
                ) { [weak self] patch in
                    Task { @MainActor in
                        self?.apply(patch, to: job.id)
                    }
                }
            } catch {
                apply(
                    .init(
                        phase: .failed,
                        progress: 0,
                        status: BrowserCookies.friendlyError(error.localizedDescription),
                        error: BrowserCookies.friendlyError(error.localizedDescription)
                    ),
                    to: job.id
                )
            }
        }
    }

    func clearFinished() {
        jobs.removeAll { $0.phase == .finished || $0.phase == .failed }
    }

    func reveal(_ job: ForgeJob) {
        guard let path = job.outputPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func apply(_ patch: ForgeJob.Patch, to id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].apply(patch)
    }
}
