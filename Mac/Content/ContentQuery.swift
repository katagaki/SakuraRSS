import Foundation
import Hanami

struct ContentQuery {

    let feedManager: FeedManager

    func articles(for location: BrowserLocation) -> [Article] {
        switch location {
        case .startPage, .allContent:
            feedManager.todayArticles() + feedManager.olderArticles(limit: 500)
        case .bookmarks:
            (try? feedManager.database.bookmarkedArticles()) ?? []
        case .feedSection(let section):
            feedManager.todayArticles(for: section) + feedManager.olderArticles(for: section, limit: 500)
        case .feed(let feedID):
            feedManager.feedsByID[feedID].map { feedManager.articles(for: $0, limit: 500) } ?? []
        case .list(let listID):
            feedManager.lists.first { $0.id == listID }.map {
                feedManager.todayArticles(for: $0) + feedManager.olderArticles(for: $0, limit: 500)
            } ?? []
        case .search(let query):
            (try? feedManager.database.searchArticles(query: query)) ?? []
        case .article:
            []
        case .bookmarkFolder(let folderID):
            feedManager.bookmarkFolders.first { $0.id == folderID }.map(feedManager.bookmarkedArticles(in:)) ?? []
        case .bookmarkTag(let tagID):
            feedManager.allBookmarkTags()
                .first { $0.id == tagID }
                .map(feedManager.bookmarkedArticles(taggedWith:)) ?? []
        }
    }
}
