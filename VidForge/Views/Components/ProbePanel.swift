import SwiftUI

struct ProbePanel: View {
    @EnvironmentObject private var store: ForgeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASSAY")
                .font(.custom("Avenir Next", size: 11).weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.4))

            if store.isProspectingPreview && store.preview == nil {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Prospecting streams…")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panelBackground)
            } else if let preview = store.preview {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preview.title)
                        .font(.custom("Avenir Next", size: 15).weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        if let uploader = preview.uploader {
                            Label(uploader, systemImage: "person.fill")
                        }
                        if let duration = preview.durationLabel {
                            Label(duration, systemImage: "clock")
                        }
                        if let res = preview.bestResolution {
                            Label(res, systemImage: "aspectratio")
                        }
                    }
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .labelStyle(.titleAndIcon)

                    if let formats = preview.formatsSummary {
                        Text("Veins: \(formats)")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(Color(red: 0.95, green: 0.7, blue: 0.4).opacity(0.8))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panelBackground)
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
