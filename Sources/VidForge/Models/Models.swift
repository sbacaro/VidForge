import Foundation

enum Alloy: String, CaseIterable, Identifiable, Codable, Sendable {
    case archivePure = "archive-pure"
    case crystal = "crystal"
    case tempered = "tempered"
    case audioIngot = "audio-ingot"

    var id: String { rawValue }

    var mark: String {
        switch self {
        case .archivePure: return "I"
        case .crystal: return "II"
        case .tempered: return "III"
        case .audioIngot: return "IV"
        }
    }

    var name: String {
        switch self {
        case .archivePure: return "Archive Pure"
        case .crystal: return "Crystal"
        case .tempered: return "Tempered"
        case .audioIngot: return "Audio Ingot"
        }
    }

    var blurb: String {
        switch self {
        case .archivePure: return "Max fidelity remux into MKV."
        case .crystal: return "Near-lossless HEVC quench."
        case .tempered: return "Everyday high-quality H.264."
        case .audioIngot: return "Best audio drawn as FLAC."
        }
    }

    var formatSelector: String {
        self == .audioIngot ? "ba/b" : "bv*+ba/b"
    }
}

enum JobPhase: String, Codable, Sendable {
    case queued, prospecting, smelting, quenching, finished, failed

    var label: String {
        switch self {
        case .queued: return "Queued"
        case .prospecting: return "Prospecting"
        case .smelting: return "Smelting"
        case .quenching: return "Quenching"
        case .finished: return "Forged"
        case .failed: return "Cracked"
        }
    }
}

struct ForgeJob: Identifiable, Sendable {
    struct Patch: Sendable {
        var phase: JobPhase?
        var progress: Double?
        var status: String?
        var title: String?
        var outputPath: String?
        var error: String?
    }

    let id: UUID
    let url: String
    let alloy: Alloy
    var title: String
    var phase: JobPhase
    var progress: Double
    var status: String
    var outputPath: String?
    var error: String?
    let createdAt: Date

    init(url: String, alloy: Alloy) {
        self.id = UUID()
        self.url = url
        self.alloy = alloy
        self.title = "Unknown ore"
        self.phase = .queued
        self.progress = 0.02
        self.status = "Heating…"
        self.createdAt = Date()
    }

    mutating func apply(_ patch: Patch) {
        if let phase = patch.phase { self.phase = phase }
        if let progress = patch.progress { self.progress = progress }
        if let status = patch.status { self.status = status }
        if let title = patch.title { self.title = title }
        if let outputPath = patch.outputPath { self.outputPath = outputPath }
        if let error = patch.error { self.error = error }
    }
}
