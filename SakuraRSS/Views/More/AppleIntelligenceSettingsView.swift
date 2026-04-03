import SwiftUI

struct AppleIntelligenceSettingsView: View {

    @AppStorage("TodaysSummary.Enabled") private var todaysSummaryEnabled: Bool = false
    @AppStorage("WhileYouSlept.Enabled") private var whileYouSleptEnabled: Bool = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "Settings.WhileYouSlept"), isOn: $whileYouSleptEnabled)
            } footer: {
                Text("Settings.WhileYouSlept.Footer")
            }

            Section {
                Toggle(String(localized: "Settings.TodaysSummary"), isOn: $todaysSummaryEnabled)
            } footer: {
                Text("Settings.TodaysSummary.Footer")
            }
        }
        .navigationTitle(String(localized: "Settings.Section.AppleIntelligence"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
    }
}
