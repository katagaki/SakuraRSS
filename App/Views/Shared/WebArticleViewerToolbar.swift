import SwiftUI

/// Shared trailing toolbar used by web-based article viewers.
struct WebArticleViewerToolbar: ToolbarContent {

    @Environment(FeedManager.self) private var feedManager
    let article: Article
    let url: URL
    @Binding var isBookmarked: Bool
    let onReload: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !article.isEphemeral {
                Button {
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
            }
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}
