import SwiftUI

struct JobRackView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ANVIL RACK")
                    .font(.custom("AvenirNext-Bold", size: 12))
                    .tracking(2)
                    .foregroundStyle(Theme.ash)
                Spacer()
                Button("Clear finished") { model.clearFinished() }
                    .buttonStyle(.plain)
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(Theme.gold.opacity(0.85))
                    .disabled(!model.jobs.contains { $0.phase == .finished || $0.phase == .failed })
            }

            if model.jobs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The anvil is cold.")
                        .font(.custom("AvenirNext-DemiBold", size: 18))
                        .foregroundStyle(Theme.mist)
                    Text("Paste a YouTube link, choose an alloy, and strike.")
                        .font(.custom("AvenirNext-Regular", size: 13))
                        .foregroundStyle(Theme.ash)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.iron.opacity(0.35)))
            } else {
                ForEach(model.jobs) { job in
                    JobRow(job: job) {
                        model.reveal(job)
                    }
                }
            }
        }
    }
}

private struct JobRow: View {
    let job: ForgeJob
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .foregroundStyle(Theme.mist)
                    Text(job.alloy.name)
                        .font(.custom("AvenirNext-Regular", size: 12))
                        .foregroundStyle(Theme.ash)
                }
                Spacer()
                Text(job.phase.label.uppercased())
                    .font(.custom("AvenirNext-Bold", size: 11))
                    .tracking(1)
                    .foregroundStyle(phaseColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(phaseColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.iron)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.ember, Theme.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * job.progress))
                        .animation(.easeInOut(duration: 0.25), value: job.progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text(job.status)
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(Theme.ash)
                    .lineLimit(2)
                Spacer()
                if job.outputPath != nil {
                    Button("Reveal in Finder", action: onReveal)
                        .buttonStyle(.plain)
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.iron.opacity(0.42)))
    }

    private var phaseColor: Color {
        switch job.phase {
        case .finished: return Theme.gold
        case .failed: return Color(red: 0.86, green: 0.32, blue: 0.24)
        default: return Theme.ember
        }
    }
}
