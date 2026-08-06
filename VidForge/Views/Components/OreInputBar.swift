import SwiftUI

struct OreInputBar: View {
    @EnvironmentObject private var store: ForgeStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ORE")
                .font(.custom("Avenir Next", size: 11).weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.4))

            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(Color(red: 0.95, green: 0.7, blue: 0.35))

                TextField("Paste a YouTube, Vimeo, or other video URL…", text: $store.oreURL)
                    .textFieldStyle(.plain)
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .focused($focused)
                    .onSubmit {
                        Task { await store.prospectPreview() }
                    }
                    .onChange(of: store.oreURL) { _, _ in
                        Task { await store.prospectPreview() }
                    }

                if !store.oreURL.isEmpty {
                    Button {
                        store.oreURL = ""
                        store.preview = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(focused ? 0.08 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: focused
                                        ? [Color(red: 0.95, green: 0.55, blue: 0.2), Color(red: 0.85, green: 0.35, blue: 0.1).opacity(0.5)]
                                        : [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}
