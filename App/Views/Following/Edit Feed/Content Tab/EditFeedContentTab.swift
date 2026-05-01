import SwiftUI

struct EditFeedContentTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedID: Int64

    @State var openMode: FeedOpenMode = .inAppViewer
    @State var articleSource: ArticleSource = .automatic

    @State var overridesEnabled: Bool = false
    @State var titleField: ContentOverrideField = .default
    @State var bodyField: ContentOverrideField = .default
    @State var authorField: ContentOverrideField = .default

    @State var hasInitialized = false

    var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        Group {
            if let feed {
                contentList(for: feed)
            } else {
                Color.clear
            }
        }
        .onAppear { initializeStateIfNeeded() }
        .onChange(of: openMode) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "openMode-\(feedID)")
        }
        .onChange(of: articleSource) { _, newValue in
            if newValue == .automatic {
                UserDefaults.standard.removeObject(forKey: "articleSource-\(feedID)")
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: "articleSource-\(feedID)")
            }
        }
        .onChange(of: overridesEnabled) { _, _ in commitOverrideIfNeeded() }
        .onChange(of: titleField) { _, _ in commitOverrideIfNeeded() }
        .onChange(of: bodyField) { _, _ in commitOverrideIfNeeded() }
        .onChange(of: authorField) { _, _ in commitOverrideIfNeeded() }
    }

    @ViewBuilder
    private func contentList(for feed: Feed) -> some View {
        Form {
            if !feed.isXFeed && !feed.isInstagramFeed && !feed.isYouTubePlaylistFeed {
                viewerSection(for: feed)
                overridesSection(for: feed)
            } else {
                Section {
                    Text(String(localized: "FeedEditSheet.Content.NotApplicable", table: "Feeds"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var pendingOverride: ContentOverride {
        ContentOverride(
            feedID: feedID,
            enabled: overridesEnabled,
            titleField: titleField,
            bodyField: bodyField,
            authorField: authorField
        )
    }
}
