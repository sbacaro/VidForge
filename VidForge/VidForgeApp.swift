import AppKit
import SwiftUI

@main
struct VidForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ForgeStore()

    var body: some Scene {
        WindowGroup("VidForge") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 640)
                .background(WindowAccessor())
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Forge") {
                Button("Paste Ore (URL)") {
                    store.pasteFromClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Open Output Folder") {
                    store.openOutputFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Clear Finished Jobs") {
                    store.clearFinished()
                }
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(store)
                .frame(width: 420, height: 280)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.forEach { window in
                window.makeKeyAndOrderFront(nil)
                window.center()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Ensures the SwiftUI window is key and on-screen after first layout.
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = "VidForge"
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
