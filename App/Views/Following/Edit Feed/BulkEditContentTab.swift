import SwiftUI

struct BulkEditContentTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedIDs: Set<Int64>
    var onApplied: () -> Void

    @State private var overridesEnabled: Bool = false
    @State private var titleField: ContentOverrideField = .default
    @State private var bodyField: ContentOverrideField = .default
    @State private var authorField: ContentOverrideField = .default

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "FeedEdit.ContentOverrides.Enable", table: "Feeds"),
                       isOn: $overridesEnabled)
                if overridesEnabled {
                    fieldPicker(titleKey: "FeedEdit.ContentOverrides.Title",
                                selection: $titleField)
                    fieldPicker(titleKey: "FeedEdit.ContentOverrides.Body",
                                selection: $bodyField)
                    fieldPicker(titleKey: "FeedEdit.ContentOverrides.Author",
                                selection: $authorField)
                }
            } header: {
                Text(String(localized: "FeedEdit.ContentOverrides", table: "Feeds"))
            } footer: {
                Text(String(
                    localized: "FeedList.BulkEdit.Content.Footer.\(feedIDs.count)",
                    table: "Feeds"
                ))
            }

            Section {
                Button {
                    applyToAll()
                } label: {
                    Text(String(
                        localized: "FeedList.BulkEdit.Content.Apply.\(feedIDs.count)",
                        table: "Feeds"
                    ))
                }
                .disabled(feedIDs.isEmpty)
            }
        }
    }

    private func fieldPicker(
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

    private func applyToAll() {
        for feedID in feedIDs {
            if overridesEnabled {
                let override = ContentOverride(
                    feedID: feedID,
                    enabled: true,
                    titleField: titleField,
                    bodyField: bodyField,
                    authorField: authorField
                )
                feedManager.setContentOverride(override, forFeedID: feedID)
            } else {
                feedManager.setContentOverride(nil, forFeedID: feedID)
            }
        }
        onApplied()
    }
}
