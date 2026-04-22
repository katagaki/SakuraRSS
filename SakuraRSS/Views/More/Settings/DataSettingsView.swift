import SwiftUI

struct DataSettingsView: View {

    var body: some View {
        List {
            DataSettingsSection()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Data", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
