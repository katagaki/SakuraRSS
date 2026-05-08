import SwiftUI

/// Overflow menu shown at the right edge of the Feed (Compact) header row.
struct CompactFeedArticleRowOverflowMenu: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article

    var body: some View {
        Menu {
            Button {
                Haptics.impact(.light)
                feedManager.toggleBookmark(article)
            } label: {
                Label(
                    feedManager.isBookmarked(article)
                        ? String(localized: "Article.RemoveBookmark", table: "Articles")
                        : String(localized: "Article.Bookmark", table: "Articles"),
                    systemImage: feedManager.isBookmarked(article) ? "bookmark.fill" : "bookmark"
                )
            }

            if let shareURL = URL(string: article.url) {
                ShareLink(item: shareURL) {
                    Label(
                        String(localized: "Article.Share", table: "Articles"),
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
