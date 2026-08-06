import AppKit
import Foundation
import SwiftUI

@MainActor
final class ForgeStore: ObservableObject {
    @Published var oreURL: String = ""
    @Published var selectedAlloy: AlloyPreset = .archivePure
    @Published var jobs: [ForgeJob] = []
    @Published var preview: MediaProbe?
    @Published var isProspectingPreview = false
    @Published var toolWarning: String?
    @Published var outputDirectory: URL

    private let engine = ForgeEngine()
    private var workerTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var isForging = false

    init() {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        outputDirectory = movies.appendingPathComponent("VidForge", isDirectory: true)
        toolWarning = BinaryLocator.missingToolsMessage
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    var canForge: Bool {
        let trimmed = oreURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && BinaryLocator.missingToolsMessage == nil
    }

    func refreshTools() {
        toolWarning = BinaryLocator.missingToolsMessage
    }

    func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            oreURL = str.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await prospectPreview() }
        }
    }

    func openOutputFolder() {
        NSWorkspace.shared.open(outputDirectory)
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = outputDirectory
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    func clearFinished() {
        jobs.removeAll { $0.phase.isTerminal }
    }

    func prospectPreview() async {
        let url = oreURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            preview = nil
            return
        }
        guard BinaryLocator.ytDlp != nil else { return }

        previewTask?.cancel()
        isProspectingPreview = true
        previewTask = Task {
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                let yt = YtDlpService()
                let result = try await yt.probe(url: url)
                guard !Task.isCancelled else { return }
                preview = result
            } catch {
                if !Task.isCancelled {
                    preview = nil
                }
            }
            isProspectingPreview = false
        }
    }

    func enqueueCurrent() {
        let url = oreURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        let job = ForgeJob(
            url: url,
            alloy: selectedAlloy,
            title: preview?.title ?? "Unknown ore",
            durationHint: preview?.durationLabel,
            resolutionHint: preview?.bestResolution
        )
        jobs.insert(job, at: 0)
        oreURL = ""
        preview = nil
        pumpQueue()
    }

    func cancelJob(_ id: UUID) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            if !jobs[index].phase.isTerminal {
                jobs[index].phase = .cancelled
                jobs[index].statusLine = "Abandoned at the forge."
            }
        }
        Task {
            await engine.cancel()
            isForging = false
            pumpQueue()
        }
    }

    func reveal(_ job: ForgeJob) {
        guard let url = job.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ job: ForgeJob) {
        guard let url = job.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func pumpQueue() {
        guard !isForging else { return }
        guard let next = jobs.first(where: { $0.phase == .queued }) else { return }

        isForging = true
        let jobID = next.id
        let url = next.url
        let alloy = next.alloy
        let output = outputDirectory

        workerTask = Task {
            await engine.forge(
                jobID: jobID,
                url: url,
                alloy: alloy,
                outputDirectory: output,
                onUpdate: { [weak self] title, phase, progress, status, resolution, duration in
                    Task { @MainActor in
                        guard let self,
                              let index = self.jobs.firstIndex(where: { $0.id == jobID })
                        else { return }
                        if let title { self.jobs[index].title = title }
                        self.jobs[index].phase = phase
                        self.jobs[index].progress = progress
                        self.jobs[index].statusLine = status
                        if let resolution { self.jobs[index].resolutionHint = resolution }
                        if let duration { self.jobs[index].durationHint = duration }
                    }
                },
                onFinished: { [weak self] result in
                    Task { @MainActor in
                        guard let self,
                              let index = self.jobs.firstIndex(where: { $0.id == jobID })
                        else { return }
                        switch result {
                        case .success(let file):
                            self.jobs[index].outputURL = file
                            self.jobs[index].phase = .finished
                            self.jobs[index].progress = 1
                        case .failure(let error):
                            if self.jobs[index].phase != .cancelled {
                                self.jobs[index].phase = .failed
                                self.jobs[index].errorMessage = error.localizedDescription
                                self.jobs[index].statusLine = error.localizedDescription
                            }
                        }
                        self.isForging = false
                        self.pumpQueue()
                    }
                }
            )
        }
    }
}
