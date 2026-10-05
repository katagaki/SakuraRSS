import Foundation
import Hanami

struct ContentQuery {

    let feedManager: FeedManager

    /// Showing a page asks for its content from the detail pane, the list and
    /// the toolbar's style item in turn, so the last result is kept until the data changes.
    private static var lastResult: QueryResult?

    private struct QueryResult {
        let location: BrowserLocation
        let revision: Int
        let articles: [Article]
    }

    func articles(for location: BrowserLocation) -> [Article] {
        let revision = feedManager.dataRevision
        if let lastResult = Self.lastResult, lastResult.location == location, lastResult.revision == revision {
            return lastResult.articles
        }
        let articles = queryArticles(for: location)
        Self.lastResult = QueryResult(location: location, revision: revision, articles: articles)
        return articles
    }

    private func queryArticles(for location: BrowserLocation) -> [Article] {
        switch location {
        case .startPage, .allContent:
            feedManager.todayArticles() + feedManager.olderArticles(limit: 500)
        case .feedSection(let section):
            feedManager.articles(for: section, limit: 500)
        case .feed, .list:
            sourceArticles(for: location)
        case .bookmarks, .bookmarkFolder, .bookmarkTag:
            bookmarkArticles(for: location)
        case .search, .topic, .person:
            matchingArticles(for: location)
        case .article, .topics, .webPage:
            []
        }
    }

    private func sourceArticles(for location: BrowserLocation) -> [Article] {
        switch location {
        case .feed(let feedID):
            feedManager.feedsByID[feedID].map { feedManager.articles(for: $0, limit: 500) } ?? []
        case .list(let listID):
            feedManager.lists.first { $0.id == listID }.map { feedManager.articles(for: $0, limit: 500) } ?? []
        default:
            []
        }
    }

    private func bookmarkArticles(for location: BrowserLocation) -> [Article] {
        switch location {
        case .bookmarkFolder(let folderID):
            feedManager.bookmarkFolders.first { $0.id == folderID }.map(feedManager.bookmarkedArticles(in:)) ?? []
        case .bookmarkTag(let tagID):
            feedManager.allBookmarkTags()
                .first { $0.id == tagID }
                .map(feedManager.bookmarkedArticles(taggedWith:)) ?? []
        default:
            (try? feedManager.database.bookmarkedArticles()) ?? []
        }
    }

    private func matchingArticles(for location: BrowserLocation) -> [Article] {
        let database = feedManager.database
        switch location {
        case .search(let query):
            return (try? database.searchArticles(query: query)) ?? []
        case .topic(let name):
            return (try? database.articlesForEntity(name: name, types: TopicKind.topic.entityTypes, limit: 300)) ?? []
        case .person(let name):
            return (try? database.articlesForEntity(name: name, types: TopicKind.person.entityTypes, limit: 300)) ?? []
        default:
            return []
        }
    }
}
