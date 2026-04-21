import SwiftUI

struct DataSettingsView: View {

    var body: some View {
        List {
            DataSettingsSection()
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Data", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
