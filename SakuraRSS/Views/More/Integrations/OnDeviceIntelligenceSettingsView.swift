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
                    Toggle(String(localized: "WhileYouSlept", table: "Settings"), isOn: $whileYouSleptEnabled)
                    Toggle(String(localized: "TodaysSummary", table: "Settings"), isOn: $todaysSummaryEnabled)
                } header: {
                    Text(String(localized: "Section.AppleIntelligence", table: "Settings"))
                } footer: {
                    Text(String(localized: "AppleIntelligence.Footer", table: "Settings"))
                }
            }

            Section {
                Toggle(String(localized: "ContentInsights", table: "Settings"), isOn: $contentInsightsEnabled)
            } footer: {
                Text(String(localized: "ContentInsights.Footer", table: "Settings"))
            }
        }
        .navigationTitle(String(localized: "Section.InsightsAndIntelligence", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
    }
}
