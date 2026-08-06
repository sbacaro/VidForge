import SwiftUI

struct ForgeQueueView: View {
    @EnvironmentObject private var store: ForgeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THE QUEUE")
                    .font(.custom("Avenir Next", size: 11).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.4))

                Spacer()

                if store.jobs.contains(where: \.phase.isTerminal) {
                    Button("Clear finished") {
                        store.clearFinished()
                    }
                    .font(.custom("Avenir Next", size: 11).weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            if store.jobs.isEmpty {
                EmptyAnvil()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.jobs) { job in
                            JobRowView(job: job)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

private struct EmptyAnvil: View {
    @State private var glow = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.9, green: 0.4, blue: 0.1).opacity(glow ? 0.25 : 0.08))
                    .frame(width: 120, height: 28)
                    .blur(radius: 10)
                    .offset(y: 36)

                Image(systemName: "hammer.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.75, green: 0.72, blue: 0.68),
                                Color(red: 0.45, green: 0.42, blue: 0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(glow ? -8 : 8))
            }

            Text("The anvil is cold.")
                .font(.custom("Avenir Next", size: 16).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.7))

            Text("Drop a URL into the ore field and strike.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(Color.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
