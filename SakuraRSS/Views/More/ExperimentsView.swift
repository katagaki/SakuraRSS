import SwiftUI

struct ExperimentsView: View {

    @AppStorage("Experiments.XProfileFeeds") private var xProfileFeedsEnabled: Bool = false

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sakura"
    }

    var body: some View {
        Form {
            Section {
                Text("Experiments.Warning \(appName)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Experiments.XProfileFeeds"), isOn: $xProfileFeedsEnabled)
            } header: {
                Text("Experiments.Section.Features")
            } footer: {
                Text("Experiments.XProfileFeeds.Footer")
            }
        }
        .navigationTitle(String(localized: "Experiments.Title"))
        .toolbarTitleDisplayMode(.inlineLarge)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
    }
}
