import Foundation

enum JobPhase: String, Codable {
    case queued
    case prospecting
    case smelting
    case quenching
    case finished
    case failed
    case cancelled

    var label: String {
        switch self {
        case .queued: return "Queued"
        case .prospecting: return "Prospecting"
        case .smelting: return "Smelting"
        case .quenching: return "Quenching"
        case .finished: return "Forged"
        case .failed: return "Cracked"
        case .cancelled: return "Abandoned"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .finished, .failed, .cancelled: return true
        default: return false
        }
    }
}

struct ForgeJob: Identifiable, Equatable {
    let id: UUID
    var url: String
    var alloy: AlloyPreset
    var title: String
    var phase: JobPhase
    var progress: Double
    var statusLine: String
    var outputURL: URL?
    var thumbnailURL: URL?
    var errorMessage: String?
    var createdAt: Date
    var durationHint: String?
    var resolutionHint: String?

    init(
        id: UUID = UUID(),
        url: String,
        alloy: AlloyPreset,
        title: String = "Unknown ore",
        phase: JobPhase = .queued,
        progress: Double = 0,
        statusLine: String = "Waiting at the anvil…",
        outputURL: URL? = nil,
        thumbnailURL: URL? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        durationHint: String? = nil,
        resolutionHint: String? = nil
    ) {
        self.id = id
        self.url = url
        self.alloy = alloy
        self.title = title
        self.phase = phase
        self.progress = progress
        self.statusLine = statusLine
        self.outputURL = outputURL
        self.thumbnailURL = thumbnailURL
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.durationHint = durationHint
        self.resolutionHint = resolutionHint
    }
}
