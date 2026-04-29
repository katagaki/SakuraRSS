import SwiftUI

struct ClearThisPageSettingsView: View {

    private var descriptionText: AttributedString {
        var attributed = AttributedString(
            String(localized: "ClearThisPage.About", table: "Settings")
            + "\n\n"
            + String(localized: "ClearThisPage.Footer", table: "Settings")
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
                Text(String(localized: "ClearThisPage.AboutHeader", table: "Settings"))
            }
        }
        .navigationTitle(String(localized: "ClearThisPage", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
    }
}
