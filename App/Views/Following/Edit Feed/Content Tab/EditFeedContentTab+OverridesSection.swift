import SwiftUI

extension EditFeedContentTab {

    @ViewBuilder
    func overridesSection(for feed: Feed) -> some View {
        Section {
            Toggle(String(localized: "FeedEdit.ContentOverrides.Enable", table: "Feeds"),
                   isOn: $overridesEnabled)

            if overridesEnabled {
                contentOverrideFieldPicker(
                    titleKey: "FeedEdit.ContentOverrides.Title",
                    selection: $titleField
                )
                contentOverrideFieldPicker(
                    titleKey: "FeedEdit.ContentOverrides.Body",
                    selection: $bodyField
                )
                contentOverrideFieldPicker(
                    titleKey: "FeedEdit.ContentOverrides.Author",
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
        titleKey: String.LocalizationValue,
        selection: Binding<ContentOverrideField>
    ) -> some View {
        Picker(String(localized: titleKey, table: "Feeds"), selection: selection) {
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
