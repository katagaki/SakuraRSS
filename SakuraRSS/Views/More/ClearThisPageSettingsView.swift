import SwiftUI

struct ClearThisPageSettingsView: View {

    var body: some View {
        List {
            Section {
                Text(
                    String(localized: "Settings.ClearThisPage.About")
                    + "\n\n"
                    + String(localized: "Settings.ClearThisPage.Footer")
                )
            } header: {
                Text("Settings.ClearThisPage.AboutHeader")
            }
        }
        .navigationTitle("Integrations.ClearThisPage")
        .toolbarTitleDisplayMode(.inline)
    }
}
