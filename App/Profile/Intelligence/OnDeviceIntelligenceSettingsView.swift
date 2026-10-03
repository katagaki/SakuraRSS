import SwiftUI
import Hanami

struct OnDeviceIntelligenceSettingsView: View {

    @Environment(FeedManager.self) private var feedManager

    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false
    @AppStorage("Intelligence.Personalization.Enabled") private var personalizationEnabled: Bool = true

    @State private var showingClearConfirmation = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "ContentInsights", table: "Settings"), isOn: $contentInsightsEnabled)
                Toggle(String(localized: "Personalization", table: "Settings"), isOn: $personalizationEnabled)
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Text(String(localized: "Personalization.ClearHistory", table: "Settings"))
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "ContentInsights.Footer", table: "Settings"))
                    Text(String(localized: "Personalization.Footer", table: "Settings"))
                }
            }
        }
        .navigationTitle(String(localized: "Section.InsightsAndIntelligence", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .confirmationDialog(
            String(localized: "Personalization.ClearHistory.Confirm.Title", table: "Settings"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "Personalization.ClearHistory", table: "Settings"),
                role: .destructive
            ) {
                feedManager.clearAccessHistory()
            }
        } message: {
            Text(String(localized: "Personalization.ClearHistory.Confirm.Message", table: "Settings"))
        }
    }
}
