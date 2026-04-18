import Foundation
import SwiftUI

@Observable
final class FeedManager {

    var feeds: [Feed] = []
    var articles: [Article] = []
    var lists: [FeedList] = []
    var isLoading = false
    var refreshTotal: Int = 0
    var refreshCompleted: Int = 0
    var refreshProgress: Double {
        guard refreshTotal > 0 else { return 0 }
        return min(max(Double(refreshCompleted) / Double(refreshTotal), 0), 1)
    }
    private(set) var dataRevision: Int = 0
    private(set) var faviconRevision: Int = 0
    private(set) var unreadCounts: [Int64: Int] = [:]
    private(set) var feedsByID: [Int64: Feed] = [:]

    /// Tracks whether at least one `markReadDebounced(_:)` call has
    /// written to the DB but has not yet run the UI-side cascade
    /// (`loadFromDatabase()` + badge refresh).
    @ObservationIgnored var hasPendingDebouncedReads: Bool = false
    @ObservationIgnored var debouncedReadFlushTask: Task<Void, Never>?

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

    func decrementUnreadCount(feedID: Int64) {
        if let count = unreadCounts[feedID], count > 0 {
            unreadCounts[feedID] = count - 1
        }
    }

    func bumpDataRevision() {
        dataRevision += 1
    }

}

enum FeedError: LocalizedError {
    case alreadyExists
    case followLimitExceeded(host: String, limit: Int)

    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            String(localized: "FeedError.AlreadyExists", table: "Feeds")
        case .followLimitExceeded(let host, let limit):
            String(localized: "FeedError.FollowLimitExceeded \(host) \(limit)", table: "Feeds")
        }
    }
}
