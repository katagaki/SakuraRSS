import Foundation
import SwiftUI

@Observable
final class FeedManager {

    var feeds: [Feed] = []
    var articles: [Article] = []
    var lists: [FeedList] = []
    var isLoading = false
    private(set) var dataRevision: Int = 0
    private(set) var faviconRevision: Int = 0
    private(set) var unreadCounts: [Int64: Int] = [:]
    private(set) var feedsByID: [Int64: Feed] = [:]

    let database = DatabaseManager.shared

    init() {
        loadFromDatabase()
    }

    func loadFromDatabase() {
        do {
            feeds = try database.allFeeds()
            feedsByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
            articles = try database.allArticles(limit: 200)
            unreadCounts = (try? database.allUnreadCounts()) ?? [:]
            lists = (try? database.allLists()) ?? []
            dataRevision += 1
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func loadFromDatabaseInBackground() async {
        let dbm = database
        do {
            let (loadedFeeds, loadedArticles, loadedUnreadCounts, loadedLists) = try await Task.detached {
                let feeds = try dbm.allFeeds()
                let articles = try dbm.allArticles(limit: 200)
                let unreadCounts = (try? dbm.allUnreadCounts()) ?? [:]
                let lists = (try? dbm.allLists()) ?? []
                return (feeds, articles, unreadCounts, lists)
            }.value
            await MainActor.run {
                self.feeds = loadedFeeds
                self.feedsByID = Dictionary(uniqueKeysWithValues: loadedFeeds.map { ($0.id, $0) })
                self.articles = loadedArticles
                self.unreadCounts = loadedUnreadCounts
                self.lists = loadedLists
                self.dataRevision += 1
            }
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    /// Notify the UI that favicons may have changed so views re-fetch them.
    func notifyFaviconChange() {
        faviconRevision += 1
    }

}

enum FeedError: LocalizedError {
    case alreadyExists
    case followLimitExceeded(host: String, limit: Int)

    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            String(localized: "FeedError.AlreadyExists")
        case .followLimitExceeded(let host, let limit):
            String(localized: "FeedError.FollowLimitExceeded \(host) \(limit)")
        }
    }
}
