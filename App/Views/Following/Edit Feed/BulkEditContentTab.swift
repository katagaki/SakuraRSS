import SwiftUI

struct BulkEditContentTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedIDs: Set<Int64>
    var onApplied: () -> Void

    @State private var viewerEnabled: Bool = false
    @State private var openMode: FeedOpenMode = .inAppViewer
    @State private var articleSource: ArticleSource = .automatic

    @State private var overridesEnabled: Bool = false
    @State private var titleField: ContentOverrideField = .default
    @State private var bodyField: ContentOverrideField = .default
    @State private var authorField: ContentOverrideField = .default

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "FeedList.BulkEdit.Viewer.Change", table: "Feeds"),
                       isOn: $viewerEnabled)
                if viewerEnabled {
                    openModePicker
                    if openMode == .inAppViewer {
                        articleSourcePicker
                    }
                }
            } header: {
                Text(String(localized: "FeedEdit.Viewer", table: "Feeds"))
            } footer: {
                Text(String(
                    localized: "FeedList.BulkEdit.Viewer.Footer.\(feedIDs.count)",
                    table: "Feeds"
                ))
            }

            Section {
                Toggle(String(localized: "FeedList.BulkEdit.ContentOverrides.Change", table: "Feeds"),
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

    private var openModePicker: some View {
        Picker(String(localized: "FeedEdit.OpenIn", table: "Feeds"), selection: $openMode) {
            Text(String(localized: "FeedEdit.OpenIn.InAppViewer", table: "Feeds"))
                .tag(FeedOpenMode.inAppViewer)
            Divider()
            Text(String(localized: "FeedEdit.OpenIn.Browser", table: "Feeds"))
                .tag(FeedOpenMode.browser)
            Text(String(localized: "FeedEdit.OpenIn.InAppBrowser", table: "Feeds"))
                .tag(FeedOpenMode.inAppBrowser)
            Text(String(localized: "FeedEdit.OpenIn.InAppBrowserReader", table: "Feeds"))
                .tag(FeedOpenMode.inAppBrowserReader)
            Divider()
            Text(String(localized: "FeedEdit.OpenIn.ClearThisPage", table: "Feeds"))
                .tag(FeedOpenMode.clearThisPage)
            Text(String(localized: "FeedEdit.OpenIn.Readability", table: "Feeds"))
                .tag(FeedOpenMode.readability)
            Text(String(localized: "FeedEdit.OpenIn.ArchivePh", table: "Feeds"))
                .tag(FeedOpenMode.archivePh)
        }
    }

    private var articleSourcePicker: some View {
        Picker(String(localized: "FeedEdit.ArticleSource", table: "Feeds"), selection: $articleSource) {
            Text(String(localized: "FeedEdit.ArticleSource.Automatic", table: "Feeds"))
                .tag(ArticleSource.automatic)
            Text(String(localized: "FeedEdit.ArticleSource.FetchText", table: "Feeds"))
                .tag(ArticleSource.fetchText)
            Text(String(localized: "FeedEdit.ArticleSource.ExtractText", table: "Feeds"))
                .tag(ArticleSource.extractText)
            Text(String(localized: "FeedEdit.ArticleSource.FeedText", table: "Feeds"))
                .tag(ArticleSource.feedText)
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
            if viewerEnabled {
                UserDefaults.standard.set(openMode.rawValue, forKey: "openMode-\(feedID)")
                if articleSource == .automatic {
                    UserDefaults.standard.removeObject(forKey: "articleSource-\(feedID)")
                } else {
                    UserDefaults.standard.set(articleSource.rawValue, forKey: "articleSource-\(feedID)")
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "openMode-\(feedID)")
                UserDefaults.standard.removeObject(forKey: "articleSource-\(feedID)")
            }

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
