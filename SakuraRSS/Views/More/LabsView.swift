import SwiftUI

struct LabsView: View {

    @AppStorage("Labs.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        Form {
            Section {
                Text("Labs.Warning \(appName)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Labs.XProfileFeeds"), isOn: $xProfileFeedsEnabled)
            } header: {
                Text("Labs.Section.Features")
            } footer: {
                Text("Labs.XProfileFeeds.Footer")
            }
        }
        .navigationTitle(String(localized: "Labs.Title"))
        .toolbarTitleDisplayMode(.inlineLarge)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
    }
}
