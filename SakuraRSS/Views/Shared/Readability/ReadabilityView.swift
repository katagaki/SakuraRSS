import SwiftUI

/// Presents an article URL through Mozilla's Readability.js in an embedded WebView.
struct ReadabilityView: View {

    @Environment(\.colorScheme) private var colorScheme
    let article: Article
    let url: URL
    @State private var isLoading = true
    @State private var reloadTrigger = 0
    @State private var isBookmarked: Bool

    init(article: Article, url: URL) {
        self.article = article
        self.url = url
        _isBookmarked = State(initialValue: article.isBookmarked)
    }

    var body: some View {
        ZStack {
            ReadabilityWebView(
                url: url,
                colorScheme: colorScheme,
                reloadTrigger: reloadTrigger,
                isLoading: $isLoading
            )
            .ignoresSafeArea()
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            WebArticleViewerToolbar(
                article: article,
                url: url,
                isBookmarked: $isBookmarked,
                onReload: { reloadTrigger &+= 1 }
            )
        }
    }
}
