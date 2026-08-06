import SwiftUI

struct JobRowView: View {
    @EnvironmentObject private var store: ForgeStore
    let job: ForgeJob

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(.custom("Avenir Next", size: 14).weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(job.alloy.title)
                            .foregroundStyle(alloyColor)
                        if let res = job.resolutionHint {
                            Text("·").foregroundStyle(Color.white.opacity(0.25))
                            Text(res)
                        }
                        if let duration = job.durationHint {
                            Text("·").foregroundStyle(Color.white.opacity(0.25))
                            Text(duration)
                        }
                    }
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
                }

                Spacer(minLength: 8)

                phaseChip
            }

            EmberProgress(progress: job.progress, phase: job.phase)

            HStack {
                Text(job.statusLine)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(2)

                Spacer()

                actions
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var phaseChip: some View {
        Text(job.phase.label.uppercased())
            .font(.custom("Avenir Next", size: 9).weight(.bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(phaseColor.opacity(0.18), in: Capsule())
            .foregroundStyle(phaseColor)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            if job.phase == .finished {
                Button("Reveal") { store.reveal(job) }
                Button("Open") { store.open(job) }
            } else if !job.phase.isTerminal {
                Button("Cancel") { store.cancelJob(job.id) }
            }
        }
        .font(.custom("Avenir Next", size: 11).weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.4))
    }

    private var alloyColor: Color {
        switch job.alloy {
        case .archivePure: return Color(red: 0.95, green: 0.78, blue: 0.42)
        case .crystal: return Color(red: 0.55, green: 0.82, blue: 0.88)
        case .tempered: return Color(red: 0.92, green: 0.55, blue: 0.32)
        case .audioIngot: return Color(red: 0.72, green: 0.82, blue: 0.55)
        }
    }

    private var phaseColor: Color {
        switch job.phase {
        case .queued: return Color.white.opacity(0.55)
        case .prospecting, .smelting, .quenching: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .finished: return Color(red: 0.55, green: 0.85, blue: 0.55)
        case .failed: return Color(red: 0.95, green: 0.4, blue: 0.35)
        case .cancelled: return Color.white.opacity(0.4)
        }
    }
}
