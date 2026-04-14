import SwiftUI

struct ClearThisPageSettingsView: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text("Settings.ClearThisPage.About")
            } header: {
                Text("Settings.ClearThisPage.AboutHeader")
            }

            Section {
                Button {
                    if let url = URL(string: "https://clearthis.page") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Text("Settings.ClearThisPage.LearnMore")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            } footer: {
                Text("Settings.ClearThisPage.Footer")
            }
        }
        .navigationTitle("Integrations.ClearThisPage")
        .toolbarTitleDisplayMode(.inline)
    }
}
