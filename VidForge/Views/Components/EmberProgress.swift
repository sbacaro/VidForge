import SwiftUI

struct EmberProgress: View {
    let progress: Double
    let phase: JobPhase

    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * min(max(progress, 0), 1)))
                    .overlay(alignment: .trailing) {
                        if !phase.isTerminal && progress > 0.05 {
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 7, height: 7)
                                .blur(radius: shimmer ? 1.5 : 0.2)
                                .offset(x: 2)
                        }
                    }
                    .shadow(color: Color(red: 0.95, green: 0.4, blue: 0.1).opacity(0.45), radius: 6, y: 0)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .animation(.easeOut(duration: 0.25), value: progress)
    }

    private var gradientColors: [Color] {
        switch phase {
        case .finished:
            return [Color(red: 0.35, green: 0.75, blue: 0.45), Color(red: 0.7, green: 0.9, blue: 0.5)]
        case .failed:
            return [Color(red: 0.7, green: 0.2, blue: 0.2), Color(red: 0.95, green: 0.4, blue: 0.3)]
        case .cancelled:
            return [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
        default:
            return [
                Color(red: 0.85, green: 0.25, blue: 0.05),
                Color(red: 0.98, green: 0.65, blue: 0.2),
                Color(red: 1.0, green: 0.88, blue: 0.55)
            ]
        }
    }
}
