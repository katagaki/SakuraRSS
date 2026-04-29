import SwiftUI

struct FeedEditContentTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedID: Int64

    @State private var openMode: FeedOpenMode = .inAppViewer
    @State private var articleSource: ArticleSource = .automatic
    @State private var hasInitialized = false

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
    }

    @ViewBuilder
    private func contentList(for feed: Feed) -> some View {
        List {
            if !feed.isXFeed && !feed.isInstagramFeed && !feed.isYouTubePlaylistFeed {
                Section {
                    openModePicker
                    if !feed.isVideoFeed && !feed.isPodcast {
                        articleSourcePicker
                    }
                } header: {
                    Text(String(localized: "FeedEdit.Behavior", table: "Feeds"))
                }
            } else {
                Section {
                    Text(String(localized: "FeedEditSheet.Content.NotApplicable", table: "Feeds"))
                        .foregroundStyle(.secondary)
                }
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

    private func initializeStateIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        let openModeRaw = UserDefaults.standard.string(forKey: "openMode-\(feedID)")
        openMode = openModeRaw.flatMap(FeedOpenMode.init(rawValue:)) ?? .inAppViewer
        let articleSourceRaw = UserDefaults.standard.string(forKey: "articleSource-\(feedID)")
        articleSource = articleSourceRaw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
    }
}
