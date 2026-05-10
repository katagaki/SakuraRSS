import SwiftUI
import Hanami

extension EditFeedContentTab {

    @ViewBuilder
    func overridesSection(for feed: Feed) -> some View {
        Section {
            Toggle(String(localized: "FeedEdit.ContentOverrides.Enable", table: "Feeds"),
                   isOn: $overridesEnabled)

            if overridesEnabled {
                contentOverrideFieldPicker(
                    title: String(localized: "FeedEdit.ContentOverrides.Title", table: "Feeds"),
                    selection: $titleField
                )
                contentOverrideFieldPicker(
                    title: String(localized: "FeedEdit.ContentOverrides.Body", table: "Feeds"),
                    selection: $bodyField
                )
                contentOverrideFieldPicker(
                    title: String(localized: "FeedEdit.ContentOverrides.Author", table: "Feeds"),
                    selection: $authorField
                )
            }

            NavigationLink {
                DisplayStylePreviewView(
                    feedID: feedID,
                    pendingOverride: overridesEnabled ? pendingOverride : nil
                )
            } label: {
                Text(String(localized: "FeedEdit.ContentOverrides.Preview", table: "Feeds"))
            }
        } header: {
            Text(String(localized: "FeedEdit.ContentOverrides", table: "Feeds"))
        } footer: {
            Text(String(localized: "FeedEdit.ContentOverrides.Footer", table: "Feeds"))
        }
    }

    private func contentOverrideFieldPicker(
        title: String,
        selection: Binding<ContentOverrideField>
    ) -> some View {
        Picker(title, selection: selection) {
            Section {
                Text(ContentOverrideField.default.localizedName).tag(ContentOverrideField.default)
                Text(ContentOverrideField.disabled.localizedName).tag(ContentOverrideField.disabled)
            }
            Section {
                Text(ContentOverrideField.title.localizedName).tag(ContentOverrideField.title)
                Text(ContentOverrideField.summary.localizedName).tag(ContentOverrideField.summary)
                Text(ContentOverrideField.content.localizedName).tag(ContentOverrideField.content)
                Text(ContentOverrideField.author.localizedName).tag(ContentOverrideField.author)
            }
        }
    }
}
