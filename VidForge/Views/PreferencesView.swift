import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var store: ForgeStore

    var body: some View {
        Form {
            Section("Output") {
                LabeledContent("Folder") {
                    Text(store.outputDirectory.path)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Button("Choose Folder…") {
                    store.chooseOutputFolder()
                }
                Button("Reveal in Finder") {
                    store.openOutputFolder()
                }
            }

            Section("Bundled Tools") {
                Text("These engines ship inside VidForge.app. No Homebrew install is required.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                LabeledContent("Helpers") {
                    Text(BinaryLocator.helpersDirectory.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                LabeledContent("yt-dlp") {
                    status(for: BinaryLocator.ytDlp)
                }
                LabeledContent("ffmpeg") {
                    status(for: BinaryLocator.ffmpeg)
                }
                LabeledContent("ffprobe") {
                    status(for: BinaryLocator.ffprobe)
                }
                Button("Recheck") {
                    store.refreshTools()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func status(for url: URL?) -> some View {
        Text(url == nil ? "Missing" : "Bundled")
            .font(.system(size: 11))
            .foregroundStyle(url == nil ? .red : .secondary)
    }
}
