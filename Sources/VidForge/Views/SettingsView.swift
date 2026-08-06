import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private let browsers = ["auto", "chrome", "chromium", "brave", "edge", "safari"]

    var body: some View {
        @Bindable var model = model

        Form {
            Section("YouTube session") {
                Picker("Browser cookies", selection: $model.preferredBrowser) {
                    ForEach(browsers, id: \.self) { browser in
                        Text(browser).tag(browser)
                    }
                }
                Text("Stay logged into YouTube in that browser. If cookie reads fail, grant Full Disk Access to VidForge in System Settings → Privacy & Security.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Recheck cookies") {
                    Task { await model.refreshEnvironment() }
                }
            }

            Section("Output") {
                Text(model.outputDirectory.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("Reveal output folder") {
                    NSWorkspace.shared.open(model.outputDirectory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
