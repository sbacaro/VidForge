import SwiftUI

struct EmberButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.05))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [
                                    Color(red: 1.0, green: 0.78, blue: 0.42),
                                    Color(red: 0.95, green: 0.48, blue: 0.18)
                                ]
                                : [Color.gray.opacity(0.35), Color.gray.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: isEnabled
                            ? Color(red: 0.95, green: 0.4, blue: 0.1).opacity(configuration.isPressed ? 0.15 : 0.45)
                            : .clear,
                        radius: configuration.isPressed ? 4 : 14,
                        y: configuration.isPressed ? 1 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.55)
    }
}

struct GhostIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(0.7))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}
