import SwiftUI

/// A navigation component that routes article taps to either the in-app detail view,
/// a Safari view controller (for allowlisted domains), or the YouTube app.
struct ArticleLink<Label: View>: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article
    @ViewBuilder let label: () -> Label

    @AppStorage("Labs.YouTubePlayer") private var youTubePlayerEnabled: Bool = false
    @State private var showSafari = false
    @State private var showYouTubePlayer = false

    private var feedOpenMode: FeedOpenMode {
        guard let feed = feedManager.feed(forArticle: article),
              let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)"),
              let mode = FeedOpenMode(rawValue: raw) else {
            return .inAppViewer
        }
        return mode
    }

    private var isXFeedArticle: Bool {
        feedManager.feed(forArticle: article)?.isXFeed == true
    }

    var body: some View {
        if article.isPodcastEpisode {
            NavigationLink(value: article) {
                label()
            }
        } else if isXFeedArticle {
            Button {
                feedManager.markRead(article)
                if let url = URL(string: article.url) {
                    openURL(url)
                }
            } label: {
                label()
            }
        } else if article.isYouTubeURL && youTubePlayerEnabled {
            Button {
                feedManager.markRead(article)
                showYouTubePlayer = true
            } label: {
                label()
            }
            .sheet(isPresented: $showYouTubePlayer) {
                YouTubePlayerView(article: article)
            }
        } else if article.isYouTubeURL {
            Button {
                feedManager.markRead(article)
                YouTubeHelper.openInApp(url: article.url)
            } label: {
                label()
            }
        } else if feedOpenMode == .browser {
            Button {
                feedManager.markRead(article)
                if let url = URL(string: article.url) {
                    openURL(url)
                }
            } label: {
                label()
            }
        } else if feedOpenMode == .inAppBrowser,
                  let url = URL(string: article.url) {
            Button {
                feedManager.markRead(article)
                showSafari = true
            } label: {
                label()
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        } else if let url = URL(string: article.url), SafariDomains.shouldOpenInSafari(url: url) {
            Button {
                feedManager.markRead(article)
                showSafari = true
            } label: {
                label()
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        } else {
            NavigationLink(value: article) {
                label()
            }
        }
    }
}
