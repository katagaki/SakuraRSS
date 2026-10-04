import Foundation
import Hanami

struct ContentQuery {

    let feedManager: FeedManager

    func articles(for location: BrowserLocation) -> [Article] {
        switch location {
        case .startPage, .allContent:
            feedManager.todayArticles() + feedManager.olderArticles(limit: 500)
        case .feedSection(let section):
            feedManager.todayArticles(for: section) + feedManager.olderArticles(for: section, limit: 500)
        case .feed, .list:
            sourceArticles(for: location)
        case .bookmarks, .bookmarkFolder, .bookmarkTag:
            bookmarkArticles(for: location)
        case .search, .topic, .person:
            matchingArticles(for: location)
        case .article, .topics:
            []
        }
    }

    private func sourceArticles(for location: BrowserLocation) -> [Article] {
        switch location {
        case .feed(let feedID):
            feedManager.feedsByID[feedID].map { feedManager.articles(for: $0, limit: 500) } ?? []
        case .list(let listID):
            feedManager.lists.first { $0.id == listID }.map {
                feedManager.todayArticles(for: $0) + feedManager.olderArticles(for: $0, limit: 500)
            } ?? []
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
