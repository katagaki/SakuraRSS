import SwiftUI

struct ClearThisPageSettingsView: View {

    private var descriptionText: AttributedString {
        var attributed = AttributedString(
            String(localized: "Settings.ClearThisPage.About")
            + "\n\n"
            + String(localized: "Settings.ClearThisPage.Footer")
        )
        let urlString = "https://clearthis.page"
        if let range = attributed.range(of: urlString),
           let url = URL(string: urlString) {
            attributed[range].link = url
        }
        return attributed
    }

    var body: some View {
        List {
            Section {
                Text(descriptionText)
            } header: {
                Text("Settings.ClearThisPage.AboutHeader")
            }
        }
        .navigationTitle("Integrations.ClearThisPage")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
    }
}
