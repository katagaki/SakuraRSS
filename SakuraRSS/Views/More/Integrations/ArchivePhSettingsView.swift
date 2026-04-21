import SwiftUI

struct ArchivePhSettingsView: View {

    private var descriptionText: AttributedString {
        var attributed = AttributedString(
            String(localized: "ArchivePh.About", table: "Settings")
            + "\n\n"
            + String(localized: "ArchivePh.Footer", table: "Settings")
        )
        let urlString = "https://archive.md"
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
                Text(String(localized: "ArchivePh.AboutHeader", table: "Settings"))
            }
        }
        .navigationTitle(String(localized: "ArchivePh", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
    }
}
