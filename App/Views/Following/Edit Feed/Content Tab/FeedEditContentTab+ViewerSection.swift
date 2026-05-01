import SwiftUI

extension FeedEditContentTab {

    @ViewBuilder
    func viewerSection(for feed: Feed) -> some View {
        Section {
            openModePicker
            if openMode == .inAppViewer {
                if !feed.isVideoFeed && !feed.isPodcast {
                    articleSourcePicker
                }
                NavigationLink {
                    ArticleViewerPreviewView(feedID: feedID)
                        .environment(feedManager)
                } label: {
                    Text(String(localized: "FeedEdit.Viewer.Preview", table: "Feeds"))
                }
            }
        } header: {
            Text(String(localized: "FeedEdit.Viewer", table: "Feeds"))
        }
    }

    var openModePicker: some View {
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

    var articleSourcePicker: some View {
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
}
