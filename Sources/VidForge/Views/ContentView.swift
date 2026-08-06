import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    FurnaceView()
                    JobRackView()
                }
                .padding(36)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.bgTop, Theme.bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.ember.opacity(0.28), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 520
            )
            SparkField()
                .opacity(0.55)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VIDFORGE")
                .font(.custom("AvenirNextCondensed-Heavy", size: 54))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: Theme.ember.opacity(0.35), radius: 18, y: 6)

            Text("Pull ore from the web. Quench it into lasting metal.")
                .font(.custom("AvenirNext-Medium", size: 16))
                .foregroundStyle(Theme.mist.opacity(0.85))

            Text(model.statusMessage)
                .font(.custom("AvenirNext-Regular", size: 13))
                .foregroundStyle(Theme.ash)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }
}

private struct SparkField: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<28 {
                    let seed = Double(i) * 17.13
                    let x = (sin(seed) * 0.5 + 0.5) * size.width
                    let speed = 18 + (seed.truncatingRemainder(dividingBy: 12))
                    let y = size.height - ((t * speed + seed * 10).truncatingRemainder(dividingBy: size.height + 40))
                    let rect = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.gold.opacity(0.35 + (sin(seed) * 0.2))))
                }
            }
        }
    }
}
