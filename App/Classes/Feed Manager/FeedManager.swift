import Foundation
import SwiftUI

@Observable
final class FeedManager {

    static let lastRefreshedAtDefaultsKey = "FeedManager.LastRefreshedAt"
    static let scopedLastRefreshedAtDefaultsKey = "FeedManager.ScopedLastRefreshedAt"

    var feeds: [Feed] = []
    var articles: [Article] = []
    var lists: [FeedList] = []
    var isLoading = false
    var refreshTotal: Int = 0
    var refreshCompleted: Int = 0
    var refreshingFeedIDs: Set<Int64> = []
    var pendingRefreshFeedIDs: [Int64] = []
    var lastRefreshedAt: Date? = UserDefaults.standard
        .object(forKey: FeedManager.lastRefreshedAtDefaultsKey) as? Date {
        didSet {
            UserDefaults.standard.set(
                lastRefreshedAt,
                forKey: FeedManager.lastRefreshedAtDefaultsKey
            )
        }
    }

    /// Per-scope last-refresh timestamps so the Home "Last updated" string can
    /// follow the active section/list/feed instead of the global counter.
    /// Stored as `[scope: epochSeconds]` in UserDefaults.
    var scopedLastRefreshedAt: [String: Date] = FeedManager.loadScopedLastRefreshedAt() {
        didSet {
            UserDefaults.standard.set(
                scopedLastRefreshedAt.mapValues { $0.timeIntervalSince1970 },
                forKey: FeedManager.scopedLastRefreshedAtDefaultsKey
            )
        }
    }

    private static func loadScopedLastRefreshedAt() -> [String: Date] {
        let raw = UserDefaults.standard.dictionary(
            forKey: FeedManager.scopedLastRefreshedAtDefaultsKey
        ) as? [String: TimeInterval] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    var searchHistory: [String] = FeedManager.loadSearchHistory() {
        didSet {
            UserDefaults.standard.set(
                searchHistory,
                forKey: FeedManager.searchHistoryDefaultsKey
            )
        }
    }

    var refreshProgress: Double {
        guard refreshTotal > 0 else { return 0 }
        let fraction = Double(refreshCompleted) / Double(refreshTotal)
        return min(max(fraction, 0), 1)
    }

    var hasActiveRefreshProgress: Bool {
        refreshTotal > 0
    }

    /// Per-scope refresh state keyed by scope identifier (e.g. `section.youtube`,
    /// `list.42`, `feed.123`). Each scope tracks its own total/completed so a
    /// pull-to-refresh in one section doesn't muddle the donut for another.
    var scopedRefreshes: [String: ScopedRefreshState] = [:]
    @ObservationIgnored var scopedRefreshTasks: [String: Task<Void, Never>] = [:]

    private(set) var dataRevision: Int = 0
    private(set) var iconRevision: Int = 0
    private(set) var unreadCounts: [Int64: Int] = [:]
    /// Per-Instagram-feed count of unread articles that are reels.
    /// Subtracted from `unreadCounts` when the user has hidden reels.
    private(set) var unreadReelsCounts: [Int64: Int] = [:]
    private(set) var feedsByID: [Int64: Feed] = [:]

    /// Queued mark-read IDs; flushed every 250ms while scrolling, on idle, or on backgrounding.
    /// Kept out of observation so scroll-driven mutations don't cascade body re-evaluations
    /// across every visible article row; views observe `readMaskRevision` instead.
    @ObservationIgnored var pendingReadIDs: Set<Int64> = []
    var readMaskRevision: Int = 0
    @ObservationIgnored var pendingReadDecrements: [Int64: Int] = [:]
    @ObservationIgnored var pendingReadReelsDecrements: [Int64: Int] = [:]
    @ObservationIgnored var refreshTask: Task<Void, Never>?

    @ObservationIgnored var currentScrollPhase: ScrollPhase = .idle
    @ObservationIgnored var pendingReadsFlushWorkItem: DispatchWorkItem?
    @ObservationIgnored var badgeUpdateWorkItem: DispatchWorkItem?

    @ObservationIgnored var contentOverrideCache: [Int64: CachedContentOverride] = [:]

    @ObservationIgnored nonisolated(unsafe) private var hideReelsObserver: NSObjectProtocol?
    @ObservationIgnored private var lastObservedHideReels: Bool =
        UserDefaults.standard.bool(forKey: FeedManager.hideInstagramReelsDefaultsKey)

    static let hideInstagramReelsDefaultsKey = "Instagram.HideReels"

    let database = DatabaseManager.shared

    init() {
        loadFromDatabase()
        hideReelsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleHideReelsChangeIfNeeded()
            }
        }
    }

    deinit {
        if let hideReelsObserver {
            NotificationCenter.default.removeObserver(hideReelsObserver)
        }
    }

    private func handleHideReelsChangeIfNeeded() {
        let current = UserDefaults.standard.bool(forKey: FeedManager.hideInstagramReelsDefaultsKey)
        guard current != lastObservedHideReels else { return }
        lastObservedHideReels = current
        bumpDataRevision()
        updateBadgeCount()
    }

    func loadFromDatabase() {
        do {
            feeds = try database.allFeeds()
            feedsByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
            articles = try database.allArticles(limit: 200)
            let rawUnreadCounts = (try? database.allUnreadCounts()) ?? [:]
            unreadCounts = FeedManager.applyRulesToUnreadCounts(rawUnreadCounts, database: database)
            let instagramFeedIDs = Set(feeds.filter { $0.isInstagramFeed }.map(\.id))
            unreadReelsCounts = (try? database.unreadReelsCounts(forFeedIDs: instagramFeedIDs)) ?? [:]
            lists = (try? database.allLists()) ?? []
            pendingReadIDs.removeAll()
            pendingReadDecrements.removeAll()
            pendingReadReelsDecrements.removeAll()
            readMaskRevision += 1
            dataRevision += 1
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func loadFromDatabaseInBackground(animated: Bool = false) async {
        let dbm = database
        do {
            let (
                loadedFeeds,
                loadedArticles,
                loadedUnreadCounts,
                loadedReelsCounts,
                loadedLists
            ) = try await Task.detached {
                let feeds = try dbm.allFeeds()
                let articles = try dbm.allArticles(limit: 200)
                let rawUnreadCounts = (try? dbm.allUnreadCounts()) ?? [:]
                let unreadCounts = FeedManager.applyRulesToUnreadCounts(rawUnreadCounts, database: dbm)
                let instagramFeedIDs = Set(feeds.filter { $0.isInstagramFeed }.map(\.id))
                let reelsCounts = (try? dbm.unreadReelsCounts(forFeedIDs: instagramFeedIDs)) ?? [:]
                let lists = (try? dbm.allLists()) ?? []
                return (feeds, articles, unreadCounts, reelsCounts, lists)
            }.value
            await MainActor.run {
                let apply = {
                    self.feeds = loadedFeeds
                    self.feedsByID = Dictionary(uniqueKeysWithValues: loadedFeeds.map { ($0.id, $0) })
                    self.articles = loadedArticles
                    self.unreadCounts = loadedUnreadCounts
                    self.unreadReelsCounts = loadedReelsCounts
                    self.lists = loadedLists
                    self.pendingReadIDs.removeAll()
                    self.pendingReadDecrements.removeAll()
                    self.pendingReadReelsDecrements.removeAll()
                    self.readMaskRevision += 1
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

    func notifyIconChange() {
        iconRevision += 1
    }

    func decrementUnreadCount(feedID: Int64) {
        if let count = unreadCounts[feedID], count > 0 {
            unreadCounts[feedID] = count - 1
        }
    }

    /// Applies per-feed decrement deltas in a single mutation.
    /// `reelsDecrements` is the subset of `decrements` attributable to Instagram reels,
    /// so the parallel `unreadReelsCounts` total stays aligned with `unreadCounts`.
    func applyUnreadDecrements(_ decrements: [Int64: Int], reelsDecrements: [Int64: Int] = [:]) {
        guard !decrements.isEmpty else { return }
        var newCounts = unreadCounts
        for (feedID, delta) in decrements {
            guard let current = newCounts[feedID], current > 0 else { continue }
            newCounts[feedID] = max(0, current - delta)
        }
        unreadCounts = newCounts
        if !reelsDecrements.isEmpty {
            var newReelsCounts = unreadReelsCounts
            for (feedID, delta) in reelsDecrements {
                guard let current = newReelsCounts[feedID], current > 0 else { continue }
                newReelsCounts[feedID] = max(0, current - delta)
            }
            unreadReelsCounts = newReelsCounts
        }
    }

    func bumpDataRevision() {
        dataRevision += 1
    }

    /// Effective unread count for `feedID` after subtracting reels when the user
    /// has the "Hide reels" Instagram setting enabled.
    func effectiveUnreadCount(forFeedID feedID: Int64) -> Int {
        let raw = unreadCounts[feedID] ?? 0
        guard raw > 0, lastObservedHideReels else { return raw }
        let reels = unreadReelsCounts[feedID] ?? 0
        return max(0, raw - reels)
    }

}

struct ScopedRefreshState: Hashable, Sendable {
    var total: Int = 0
    var completed: Int = 0
    var refreshingFeedIDs: Set<Int64> = []
    var pendingFeedIDs: [Int64] = []

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    var hasActiveProgress: Bool { total > 0 }
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
