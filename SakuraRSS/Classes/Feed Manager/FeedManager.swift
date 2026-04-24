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
    var nlpTotal: Int = 0
    var nlpCompleted: Int = 0

    var refreshProgress: Double {
        let hasRefresh = refreshTotal > 0
        let hasNLP = nlpTotal > 0
        guard hasRefresh || hasNLP else { return 0 }
        let refreshFraction: Double = hasRefresh
            ? Double(refreshCompleted) / Double(refreshTotal)
            : 1.0
        let nlpFraction: Double = hasNLP
            ? Double(nlpCompleted) / Double(nlpTotal)
            : 0.0
        return min(max(refreshFraction * 0.8 + nlpFraction * 0.2, 0), 1)
    }

    var hasActiveRefreshProgress: Bool {
        refreshTotal > 0 || nlpTotal > 0
    }
    private(set) var dataRevision: Int = 0
    private(set) var faviconRevision: Int = 0
    private(set) var unreadCounts: [Int64: Int] = [:]
    private(set) var feedsByID: [Int64: Feed] = [:]

    /// Queued mark-read IDs; flushed on scroll idle or backgrounding.
    var pendingReadIDs: Set<Int64> = []
    @ObservationIgnored var refreshTask: Task<Void, Never>?

    @ObservationIgnored var currentScrollPhase: ScrollPhase = .idle

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

    func loadFromDatabaseInBackground(animated: Bool = false) async {
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
                let apply = {
                    self.feeds = loadedFeeds
                    self.feedsByID = Dictionary(uniqueKeysWithValues: loadedFeeds.map { ($0.id, $0) })
                    self.articles = loadedArticles
                    self.unreadCounts = loadedUnreadCounts
                    self.lists = loadedLists
                    self.dataRevision += 1
                }
                if animated {
                    withAnimation(.smooth.speed(2.0)) { apply() }
                } else {
                    apply()
                }
            }
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func notifyFaviconChange() {
        faviconRevision += 1
    }

    func decrementUnreadCount(feedID: Int64) {
        if let count = unreadCounts[feedID], count > 0 {
            unreadCounts[feedID] = count - 1
        }
    }

    /// Applies per-feed decrement deltas in a single mutation.
    func applyUnreadDecrements(_ decrements: [Int64: Int]) {
        guard !decrements.isEmpty else { return }
        var newCounts = unreadCounts
        for (feedID, delta) in decrements {
            guard let current = newCounts[feedID], current > 0 else { continue }
            newCounts[feedID] = max(0, current - delta)
        }
        unreadCounts = newCounts
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
