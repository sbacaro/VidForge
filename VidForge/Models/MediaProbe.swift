import Foundation

struct MediaProbe: Equatable {
    var title: String
    var uploader: String?
    var duration: TimeInterval?
    var webpageURL: String?
    var thumbnail: String?
    var formatsSummary: String?
    var bestResolution: String?

    var durationLabel: String? {
        guard let duration else { return nil }
        let total = Int(duration.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
