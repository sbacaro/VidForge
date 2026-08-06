import SwiftUI

struct AtmosphereBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.11, green: 0.09, blue: 0.08),
                    Color(red: 0.05, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft forge glow — coal bed at the bottom.
            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.42, blue: 0.08).opacity(0.28),
                    Color(red: 0.55, green: 0.12, blue: 0.02).opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 20,
                endRadius: 520
            )
            .blur(radius: 8)
            .offset(y: drift ? -8 : 8)

            // Side ember accents
            Circle()
                .fill(Color(red: 0.9, green: 0.35, blue: 0.05).opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -280, y: drift ? 80 : 120)

            Circle()
                .fill(Color(red: 0.2, green: 0.45, blue: 0.55).opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 340, y: drift ? -40 : -80)

            // Fine soot grain
            Canvas { context, size in
                for i in 0..<80 {
                    let x = CGFloat((i * 67) % Int(size.width))
                    let y = CGFloat((i * 97) % Int(size.height))
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.03)))
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}
