import SwiftUI

/// A navigation component that routes article taps to either the in-app detail view,
/// a Safari view controller (for allowlisted domains), or the YouTube app.
/// On iPad with a split view, articles that would normally push onto a NavigationStack
/// are instead shown in the detail column via the `iPadArticleSelection` environment binding.
struct ArticleLink<Label: View>: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.iPadArticleSelection) private var iPadArticleSelection
    let article: Article
    var onShowYouTubePlayer: ((Article) -> Void)?
    var onNavigate: ((Article) -> Void)?
    @ViewBuilder let label: () -> Label

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @State private var showSafari = false

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

    private var isInstagramFeedArticle: Bool {
        feedManager.feed(forArticle: article)?.isInstagramFeed == true
    }

    /// Whether this article should navigate to the iPad detail column
    /// instead of pushing onto the NavigationStack.
    private var usesIPadDetailColumn: Bool {
        iPadArticleSelection != nil
    }

    private func selectForIPadDetail() {
        feedManager.markRead(article)
        iPadArticleSelection?.wrappedValue = article
    }

    var body: some View {
        Group {
            if article.isPodcastEpisode {
                if usesIPadDetailColumn {
                    Button { selectForIPadDetail() } label: { label() }
                } else if let onNavigate {
                    Button { onNavigate(article) } label: { label() }
                } else {
                    NavigationLink(value: article) { label() }
                }
            } else if isXFeedArticle || isInstagramFeedArticle {
                Button {
                    feedManager.markRead(article)
                    if let url = URL(string: article.url) {
                        openURL(url)
                    }
                } label: {
                    label()
                }
            } else if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                if usesIPadDetailColumn {
                    Button { selectForIPadDetail() } label: { label() }
                } else {
                    Button {
                        feedManager.markRead(article)
                        onShowYouTubePlayer?(article)
                    } label: {
                        label()
                    }
                }
            } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
                Button {
                    feedManager.markRead(article)
                    YouTubeHelper.openInApp(url: article.url)
                } label: {
                    label()
                }
            } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                Button {
                    feedManager.markRead(article)
                    showSafari = true
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
            } else if feedOpenMode == .inAppBrowser {
                Button {
                    feedManager.markRead(article)
                    showSafari = true
                } label: {
                    label()
                }
            } else if let url = URL(string: article.url), OpenInBrowserDomains.shouldOpenInBrowser(url: url) {
                Button {
                    feedManager.markRead(article)
                    showSafari = true
                } label: {
                    label()
                }
            } else {
                if usesIPadDetailColumn {
                    Button { selectForIPadDetail() } label: { label() }
                } else if let onNavigate {
                    Button { onNavigate(article) } label: { label() }
                } else {
                    NavigationLink(value: article) { label() }
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
