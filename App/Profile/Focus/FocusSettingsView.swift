import SwiftUI
import Hanami

struct FocusSettingsView: View {

    @Environment(FeedManager.self) private var feedManager

    var body: some View {
        List {
            Section {
                Text(String(localized: "Focus.Settings.Explanation", table: "Settings"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if feedManager.isFocusActive {
                Section {
                    Label(
                        String(localized: "Focus.Settings.Active", table: "Settings"),
                        systemImage: "moon.fill"
                    )
                }
            }

            Section {
                FocusSetupStep(number: 1, text: String(localized: "Focus.Settings.Setup.Step1", table: "Settings"))
                FocusSetupStep(number: 2, text: String(localized: "Focus.Settings.Setup.Step2", table: "Settings"))
                FocusSetupStep(number: 3, text: String(localized: "Focus.Settings.Setup.Step3", table: "Settings"))
                FocusSetupStep(number: 4, text: String(localized: "Focus.Settings.Setup.Step4", table: "Settings"))
            } header: {
                Text(String(localized: "Focus.Settings.Setup.Title", table: "Settings"))
            }

            #if !targetEnvironment(macCatalyst)
            Section {
                Button {
                    if let url = URL(string: "App-Prefs:") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(
                        String(localized: "Focus.Settings.OpenSettings", table: "Settings"),
                        systemImage: "gearshape"
                    )
                }
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Focus", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct FocusSetupStep: View {

    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(minWidth: 16, alignment: .center)
            Text(text)
        }
    }
}
