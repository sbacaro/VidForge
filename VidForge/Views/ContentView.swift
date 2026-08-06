import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ForgeStore
    @State private var emberPulse = false

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(spacing: 0) {
                BrandHeader(emberPulse: emberPulse)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        OreInputBar()
                        AlloyPicker()
                        if store.preview != nil || store.isProspectingPreview {
                            ProbePanel()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                        ForgeActionBar()
                    }
                    .frame(maxWidth: 520, alignment: .leading)

                    ForgeQueueView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .padding(.top, 12)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: store.preview?.title)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                emberPulse = true
            }
            store.refreshTools()
        }
        .onDrop(of: [.url, .plainText], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        store.oreURL = url.absoluteString
                        await store.prospectPreview()
                    }
                }
                return true
            }
            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                    guard let text = value as? String else { return }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.contains("://") else { return }
                    Task { @MainActor in
                        store.oreURL = trimmed
                        await store.prospectPreview()
                    }
                }
                return true
            }
        }
        return false
    }
}

private struct BrandHeader: View {
    let emberPulse: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("VIDFORGE")
                    .font(.custom("Avenir Next Condensed", size: 42).weight(.heavy))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.93, blue: 0.82),
                                Color(red: 0.92, green: 0.72, blue: 0.38)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.12).opacity(emberPulse ? 0.55 : 0.2), radius: emberPulse ? 18 : 6)

                Text("Pull ore from the web. Quench it into lasting metal.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            Text("SELF-CONTAINED · BUNDLED ENGINE")
                .font(.custom("Avenir Next", size: 10).weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.bottom, 8)
        }
    }
}

private struct ForgeActionBar: View {
    @EnvironmentObject private var store: ForgeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let warning = store.toolWarning {
                Text(warning)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.45))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 12) {
                Button {
                    store.enqueueCurrent()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                        Text("Strike the Anvil")
                            .font(.custom("Avenir Next", size: 15).weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(!store.canForge)
                .keyboardShortcut(.return, modifiers: .command)

                Button {
                    store.chooseOutputFolder()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(GhostIconButtonStyle())
                .help("Choose output folder")
            }

            Text("Output → \(store.outputDirectory.path)")
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(Color.white.opacity(0.35))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
