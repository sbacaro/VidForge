import Foundation

/// Quality "alloys" — each one shapes how ore is forged.
enum AlloyPreset: String, CaseIterable, Identifiable, Codable {
    case archivePure
    case crystal
    case tempered
    case audioIngot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .archivePure: return "Archive Pure"
        case .crystal: return "Crystal"
        case .tempered: return "Tempered"
        case .audioIngot: return "Audio Ingot"
        }
    }

    var subtitle: String {
        switch self {
        case .archivePure:
            return "Maximum fidelity. Remux when possible; otherwise ProRes."
        case .crystal:
            return "Visually lossless HEVC. Small file, archival clarity."
        case .tempered:
            return "High-bitrate H.264. Universal playback."
        case .audioIngot:
            return "Best audio only — FLAC when available, else best lossy."
        }
    }

    var badge: String {
        switch self {
        case .archivePure: return "MAX"
        case .crystal: return "HEVC"
        case .tempered: return "H.264"
        case .audioIngot: return "AUDIO"
        }
    }

    /// yt-dlp format selectors tuned for quality.
    var formatSelector: String {
        switch self {
        case .archivePure, .crystal, .tempered:
            // Prefer separate streams merged by ffmpeg for highest quality.
            return "bv*+ba/b"
        case .audioIngot:
            return "ba/b"
        }
    }

    var preferredContainer: String {
        switch self {
        case .archivePure: return "mkv"
        case .crystal: return "mp4"
        case .tempered: return "mp4"
        case .audioIngot: return "m4a"
        }
    }

    var heatColor: String {
        switch self {
        case .archivePure: return "alloyArchive"
        case .crystal: return "alloyCrystal"
        case .tempered: return "alloyTempered"
        case .audioIngot: return "alloyAudio"
        }
    }
}
