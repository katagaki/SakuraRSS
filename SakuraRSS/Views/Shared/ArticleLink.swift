import SwiftUI

/// A navigation component that routes article taps to either the in-app detail view,
/// a Safari view controller (for allowlisted domains), or the YouTube app.
struct ArticleLink<Label: View>: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @ViewBuilder let label: () -> Label

    @State private var showSafari = false

    var body: some View {
        if article.isPodcastEpisode {
            NavigationLink(value: article) {
                label()
            }
        } else if article.isYouTubeURL {
            Button {
                feedManager.markRead(article)
                YouTubeHelper.openInApp(url: article.url)
            } label: {
                label()
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
