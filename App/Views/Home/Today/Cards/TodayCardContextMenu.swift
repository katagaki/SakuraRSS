import SwiftUI

/// Long-press context menu shared by all Today card carousels (excluding the
/// Apple Intelligence summary section). The Mark action label adapts to the
/// feed kind: podcast → Listened, video → Watched, otherwise → Read.
struct TodayCardContextMenu: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article

    var body: some View {
        let isRead = feedManager.isRead(article)
        Button {
            feedManager.toggleRead(article)
        } label: {
            Label(markActionTitle(isRead: isRead), systemImage: markActionIcon(isRead: isRead))
        }
        Button {
            feedManager.toggleBookmark(article)
        } label: {
            Label(
                article.isBookmarked
                    ? String(localized: "Article.RemoveBookmark", table: "Articles")
                    : String(localized: "Article.Bookmark", table: "Articles"),
                systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
            )
        }
    }

    private func markActionTitle(isRead: Bool) -> String {
        switch articleKind {
        case .podcast:
            return isRead
                ? String(localized: "Article.MarkUnlistened", table: "Articles")
                : String(localized: "Article.MarkListened", table: "Articles")
        case .video:
            return isRead
                ? String(localized: "Article.MarkUnwatched", table: "Articles")
                : String(localized: "Article.MarkWatched", table: "Articles")
        case .article:
            return isRead
                ? String(localized: "Article.MarkUnread", table: "Articles")
                : String(localized: "Article.MarkRead", table: "Articles")
        }
    }

    private func markActionIcon(isRead: Bool) -> String {
        switch articleKind {
        case .podcast, .video:
            return isRead ? "arrow.uturn.backward" : "checkmark"
        case .article:
            return isRead ? "envelope" : "envelope.open"
        }
    }

    private var articleKind: ArticleKind {
        if article.isPodcastEpisode { return .podcast }
        guard let feed = feedManager.feedsByID[article.feedID] else { return .article }
        if feed.isPodcast { return .podcast }
        if feed.isVideoFeed || feed.isYouTubeFeed || feed.isVimeoFeed { return .video }
        return .article
    }

    private enum ArticleKind {
        case podcast, video, article
    }
}
