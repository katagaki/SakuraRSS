import SwiftUI

extension FeedEditContentTab {

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
                .environment(feedManager)
            } label: {
                Text(String(localized: "FeedEdit.ContentOverrides.Preview", table: "Feeds"))
            }
        } header: {
            Text(String(localized: "FeedEdit.ContentOverrides", table: "Feeds"))
        }
    }

    private func contentOverrideFieldPicker(
        titleKey: String.LocalizationValue,
        selection: Binding<ContentOverrideField>
    ) -> some View {
        Picker(String(localized: titleKey, table: "Feeds"), selection: selection) {
            ForEach(ContentOverrideField.allCases, id: \.self) { field in
                Text(field.localizedName).tag(field)
            }
        }
    }
}
