import SwiftUI
import FoundationModels

struct OnDeviceIntelligenceSettingsView: View {

    @AppStorage("TodaysSummary.Enabled") private var todaysSummaryEnabled: Bool = false
    @AppStorage("WhileYouSlept.Enabled") private var whileYouSleptEnabled: Bool = false
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        List {
            if isAppleIntelligenceAvailable {
                Section {
                    Toggle("Settings.WhileYouSlept", isOn: $whileYouSleptEnabled)
                    Toggle("Settings.TodaysSummary", isOn: $todaysSummaryEnabled)
                } header: {
                    Text("Settings.Section.AppleIntelligence")
                } footer: {
                    Text("Settings.AppleIntelligence.Footer")
                }
            }

            Section {
                Toggle("Settings.ContentInsights", isOn: $contentInsightsEnabled)
            } footer: {
                Text("Settings.ContentInsights.Footer")
            }
        }
        .navigationTitle("Settings.Section.InsightsAndIntelligence")
        .toolbarTitleDisplayMode(.inline)
    }
}
