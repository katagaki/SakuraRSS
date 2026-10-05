import Hanami
import SwiftUI

struct IntelligenceSettingsPane: View {

    let feedManager: FeedManager
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled = false
    @AppStorage("Intelligence.Personalization.Enabled") private var personalizationEnabled = true
    @State private var isConfirmingClear = false

    var body: some View {
        SettingsForm {
            Group {
                LabeledContent(SettingsText.settings("Section.InsightsAndIntelligence")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(SettingsText.settings("ContentInsights"), isOn: $contentInsightsEnabled)
                        SettingsNote(text: SettingsText.settings("ContentInsights.Footer"))
                            .padding(.leading, 20)
                        Toggle(SettingsText.settings("Personalization"), isOn: $personalizationEnabled)
                            .padding(.top, 6)
                        SettingsNote(text: SettingsText.settings("Personalization.Footer"))
                            .padding(.leading, 20)
                        Button(SettingsText.settings("Personalization.ClearHistory") + "…") {
                            isConfirmingClear = true
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .confirmationDialog(
            SettingsText.settings("Personalization.ClearHistory.Confirm.Title"),
            isPresented: $isConfirmingClear
        ) {
            Button(SettingsText.settings("Personalization.ClearHistory"), role: .destructive) {
                feedManager.clearAccessHistory()
            }
        } message: {
            Text(SettingsText.settings("Personalization.ClearHistory.Confirm.Message"))
        }
    }
}
