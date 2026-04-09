import SwiftUI
import FoundationModels

struct OnDeviceIntelligenceSettingsView: View {

    @AppStorage("TodaysSummary.Enabled") private var todaysSummaryEnabled: Bool = false
    @AppStorage("WhileYouSlept.Enabled") private var whileYouSleptEnabled: Bool = false
    @AppStorage("Intelligence.SimilarContent.Enabled") private var similarContentEnabled: Bool = false
    @AppStorage("Intelligence.TopicsPeople.Enabled") private var topicsPeopleEnabled: Bool = false

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
                Toggle("Settings.SimilarContent", isOn: $similarContentEnabled)
            } footer: {
                Text("Settings.SimilarContent.Footer")
            }

            Section {
                Toggle("Settings.TopicsPeople", isOn: $topicsPeopleEnabled)
            } footer: {
                Text("Settings.TopicsPeople.Footer")
            }
        }
        .navigationTitle("Settings.Section.InsightsAndIntelligence")
        .toolbarTitleDisplayMode(.inline)
    }
}
