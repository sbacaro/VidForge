import SwiftUI

struct FurnaceView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var urlFocused: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 18) {
            fieldLabel("Ore")
            HStack(spacing: 12) {
                TextField("Paste a YouTube URL…", text: $model.urlText)
                    .textFieldStyle(.plain)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.iron.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.gold.opacity(urlFocused ? 0.55 : 0.18), lineWidth: 1)
                    )
                    .focused($urlFocused)
                    .onSubmit { model.strike() }

                Button("Strike") { model.strike() }
                    .buttonStyle(StrikeButtonStyle())
                    .disabled(model.busy || model.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            fieldLabel("Alloy")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Alloy.allCases) { alloy in
                    Button {
                        model.selectedAlloy = alloy
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(alloy.mark)
                                .font(.custom("AvenirNextCondensed-Bold", size: 12))
                                .foregroundStyle(Theme.ember)
                            Text(alloy.name)
                                .font(.custom("AvenirNext-DemiBold", size: 16))
                                .foregroundStyle(Theme.mist)
                            Text(alloy.blurb)
                                .font(.custom("AvenirNext-Regular", size: 12))
                                .foregroundStyle(Theme.ash)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.iron.opacity(model.selectedAlloy == alloy ? 0.85 : 0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    model.selectedAlloy == alloy ? Theme.ember.opacity(0.7) : Theme.gold.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.18))
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.custom("AvenirNext-Bold", size: 11))
            .tracking(1.6)
            .foregroundStyle(Theme.ash)
    }
}

struct StrikeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-Bold", size: 15))
            .foregroundStyle(Theme.bgTop)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
