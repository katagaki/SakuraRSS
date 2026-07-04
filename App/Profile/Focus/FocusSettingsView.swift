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

            #if !targetEnvironment(macCatalyst)
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
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
