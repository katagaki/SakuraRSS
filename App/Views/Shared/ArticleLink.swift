import SwiftUI

/// Routes article taps based on the per-feed open mode; iPad splits route to the detail column.
struct ArticleLink<Label: View>: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.iPadArticleSelection) private var iPadArticleSelection
    let article: Article
    var onNavigate: ((Article) -> Void)?
    /// When false, opening the article does not mark it as read.
    /// Used by the Cards style where the swipe gesture is the canonical read trigger.
    var marksRead: Bool = true
    @ViewBuilder let label: () -> Label

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @State private var showSafari = false
    @State private var showSafariReader = false
    private let mediaPresenter = MediaPresenter.shared

    private var feedOpenMode: FeedOpenMode {
        guard let feed = feedManager.feed(forArticle: article),
              let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)"),
              let mode = FeedOpenMode(rawValue: raw) else {
            return .inAppViewer
        }
        return mode
    }

    private var usesIPadDetailColumn: Bool {
        iPadArticleSelection != nil
    }

    private func markReadIfEnabled() {
        guard marksRead else { return }
        feedManager.markRead(article)
    }

    private func selectForIPadDetail() {
        markReadIfEnabled()
        iPadArticleSelection?.wrappedValue = article
    }

    var body: some View {
        Group {
            if article.isPodcastEpisode {
                if usesIPadDetailColumn {
                    Button { selectForIPadDetail() } label: { label() }
                } else {
                    Button {
                        markReadIfEnabled()
                        mediaPresenter.presentPodcast(article)
                    } label: {
                        label()
                    }
                }
            } else if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                if usesIPadDetailColumn {
                    Button { selectForIPadDetail() } label: { label() }
                } else {
                    Button {
                        markReadIfEnabled()
                        mediaPresenter.presentYouTube(article)
                    } label: {
                        label()
                    }
                }
            } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
                Button {
                    markReadIfEnabled()
                    YouTubeHelper.openInApp(url: article.url)
                } label: {
                    label()
                }
            } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                Button {
                    markReadIfEnabled()
                    showSafari = true
                } label: {
                    label()
                }
            } else if feedOpenMode == .browser {
                Button {
                    markReadIfEnabled()
                    if let url = URL(string: article.url) {
                        openURL(url)
                    }
                } label: {
                    label()
                }
            } else if feedOpenMode == .inAppBrowser {
                Button {
                    markReadIfEnabled()
                    showSafari = true
                } label: {
                    label()
                }
            } else if feedOpenMode == .inAppBrowserReader {
                Button {
                    markReadIfEnabled()
                    showSafariReader = true
                } label: {
                    label()
                }
            } else if feedOpenMode == .clearThisPage || feedOpenMode == .archivePh {
                if usesIPadDetailColumn {
                    Button { selectForIPadDetail() } label: { label() }
                } else if let onNavigate {
                    Button { onNavigate(article) } label: { label() }
                } else {
                    NavigationLink(value: article) { label() }
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
        .sheet(isPresented: $showSafariReader) {
            if let url = URL(string: article.url) {
                SafariView(url: url, entersReaderIfAvailable: true)
                    .ignoresSafeArea()
            }
        }
    }
}
