import SwiftUI

struct ReadabilitySettingsView: View {

    private var descriptionText: AttributedString {
        var attributed = AttributedString(
            String(localized: "Readability.About", table: "Settings")
            + "\n\n"
            + String(localized: "Readability.Footer", table: "Settings")
        )
        let urlString = "https://github.com/mozilla/readability"
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
                Text(String(localized: "Readability.AboutHeader", table: "Settings"))
            }
        }
        .navigationTitle(String(localized: "Readability", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
    }
}
