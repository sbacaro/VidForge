import SwiftUI

struct AlloyPicker: View {
    @EnvironmentObject private var store: ForgeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALLOY")
                .font(.custom("Avenir Next", size: 11).weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.4))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AlloyPreset.allCases) { alloy in
                    AlloyCard(alloy: alloy, selected: store.selectedAlloy == alloy) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.selectedAlloy = alloy
                        }
                    }
                }
            }
        }
    }
}

private struct AlloyCard: View {
    let alloy: AlloyPreset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(alloy.title)
                        .font(.custom("Avenir Next", size: 14).weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                    Spacer()
                    Text(alloy.badge)
                        .font(.custom("Avenir Next", size: 9).weight(.bold))
                        .tracking(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.22), in: Capsule())
                        .foregroundStyle(accent)
                }

                Text(alloy.subtitle)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.09 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? accent.opacity(0.75) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var accent: Color {
        switch alloy {
        case .archivePure: return Color(red: 0.95, green: 0.78, blue: 0.42)
        case .crystal: return Color(red: 0.55, green: 0.82, blue: 0.88)
        case .tempered: return Color(red: 0.92, green: 0.55, blue: 0.32)
        case .audioIngot: return Color(red: 0.72, green: 0.82, blue: 0.55)
        }
    }
}
