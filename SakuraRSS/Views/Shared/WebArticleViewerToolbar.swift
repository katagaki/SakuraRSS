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
            Button {
                isBookmarked.toggle()
                feedManager.toggleBookmark(article)
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}
