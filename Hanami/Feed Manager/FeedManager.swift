import Foundation
import SwiftUI

@Observable
public final class FeedManager {

    public static let lastRefreshedAtDefaultsKey = "FeedManager.LastRefreshedAt"
    public static let scopedLastRefreshedAtDefaultsKey = "FeedManager.ScopedLastRefreshedAt"

    public var feeds: [Feed] = []
    public var articles: [Article] = []
    public var lists: [FeedList] = []
    public var isLoading = false
    public var isStopping = false
    public var refreshTotal: Int = 0
    public var refreshCompleted: Int = 0
    public var refreshingFeedIDs: Set<Int64> = []
    public var pendingRefreshFeedIDs: [Int64] = []
    public var lastRefreshedAt: Date? = UserDefaults.standard
        .object(forKey: FeedManager.lastRefreshedAtDefaultsKey) as? Date {
        didSet {
            UserDefaults.standard.set(
                lastRefreshedAt,
                forKey: FeedManager.lastRefreshedAtDefaultsKey
            )
        }
    }

    public var scopedLastRefreshedAt: [String: Date] = FeedManager.loadScopedLastRefreshedAt() {
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

    /// Re-reads refresh timestamps from `UserDefaults` so the foreground
    /// instance picks up writes made by a separate `FeedManager` running in a
    /// `BGAppRefreshTask` while the app was suspended.
    public func reloadRefreshTimestampsFromDefaults() {
        let storedLast = UserDefaults.standard.object(
            forKey: FeedManager.lastRefreshedAtDefaultsKey
        ) as? Date
        if storedLast != lastRefreshedAt {
            lastRefreshedAt = storedLast
        }
        let storedScoped = FeedManager.loadScopedLastRefreshedAt()
        if storedScoped != scopedLastRefreshedAt {
            scopedLastRefreshedAt = storedScoped
        }
    }

    public var searchHistory: [String] = FeedManager.loadSearchHistory() {
        didSet {
            UserDefaults.standard.set(
                searchHistory,
                forKey: FeedManager.searchHistoryDefaultsKey
            )
        }
    }

    public var refreshProgress: Double {
        guard refreshTotal > 0 else { return 0 }
        let fraction = Double(refreshCompleted) / Double(refreshTotal)
        return min(max(fraction, 0), 1)
    }

    public var hasActiveRefreshProgress: Bool {
        refreshTotal > 0
    }

    /// Per-scope refresh state keyed by scope identifier (e.g. `section.youtube`,
    /// `list.42`, `feed.123`). Each scope tracks its own total/completed so a
    /// pull-to-refresh in one section doesn't muddle the donut for another.
    public var scopedRefreshes: [String: ScopedRefreshState] = [:]
    @ObservationIgnored public var scopedRefreshTasks: [String: Task<Void, Never>] = [:]

    public private(set) var dataRevision: Int = 0
    public private(set) var iconRevision: Int = 0
    public private(set) var unreadCounts: [Int64: Int] = [:]
    /// Per-Instagram-feed count of unread articles that are reels.
    /// Subtracted from `unreadCounts` when the user has hidden reels.
    public private(set) var unreadReelsCounts: [Int64: Int] = [:]
    public private(set) var feedsByID: [Int64: Feed] = [:]

    /// Queued mark-read IDs; flushed every 250ms while scrolling, on idle, or on backgrounding.
    /// Kept out of observation so scroll-driven mutations don't cascade body re-evaluations
    /// across every visible article row; views observe `readMaskRevision` instead.
    @ObservationIgnored public var pendingReadIDs: Set<Int64> = []
    /// Read-state overrides for explicit toggles, so `isRead` stays correct for cached
    /// `Article` snapshots held outside `articles` (e.g. TodayManager) until they refresh.
    @ObservationIgnored public var stagedReadChanges: [Int64: Bool] = [:]
    /// Same staging mechanism for bookmark state, consulted by `isBookmarked`.
    @ObservationIgnored public var stagedBookmarkChanges: [Int64: Bool] = [:]
    public var readMaskRevision: Int = 0
    @ObservationIgnored public var pendingReadDecrements: [Int64: Int] = [:]
    @ObservationIgnored public var pendingReadReelsDecrements: [Int64: Int] = [:]
    @ObservationIgnored public var refreshTask: Task<Void, Never>?

    @ObservationIgnored public var pendingReadsFlushWorkItem: DispatchWorkItem?
    @ObservationIgnored public var badgeUpdateWorkItem: DispatchWorkItem?

    @ObservationIgnored public var contentOverrideCache: [Int64: CachedContentOverride] = [:]

    @ObservationIgnored nonisolated(unsafe) private var userDefaultsObserver: NSObjectProtocol?
    @ObservationIgnored private var lastObservedHideReels: Bool =
        UserDefaults.standard.bool(forKey: FeedManager.hideInstagramReelsDefaultsKey)

    public static let hideInstagramReelsDefaultsKey = "Instagram.HideReels"

    public let database = DatabaseManager.shared

    public init() {
        loadFromDatabase()
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleHideReelsChangeIfNeeded()
                self?.reloadRefreshTimestampsFromDefaults()
            }
        }
    }

    deinit {
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
    }

    private func handleHideReelsChangeIfNeeded() {
        let current = UserDefaults.standard.bool(forKey: FeedManager.hideInstagramReelsDefaultsKey)
        guard current != lastObservedHideReels else { return }
        lastObservedHideReels = current
        bumpDataRevision()
        updateBadgeCount()
    }

    public func loadFromDatabase() {
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
            let freshArticleIDs = Set(articles.map(\.id))
            stagedReadChanges = stagedReadChanges.filter { !freshArticleIDs.contains($0.key) }
            stagedBookmarkChanges = stagedBookmarkChanges.filter { !freshArticleIDs.contains($0.key) }
            readMaskRevision += 1
            dataRevision += 1
        } catch {
            log("FeedManager", "Failed to load from database: \(error)")
        }
    }

    public func loadFromDatabaseInBackground(animated: Bool = false) async {
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
                    let freshArticleIDs = Set(loadedArticles.map(\.id))
                    self.stagedReadChanges = self.stagedReadChanges.filter { !freshArticleIDs.contains($0.key) }
                    self.stagedBookmarkChanges = self.stagedBookmarkChanges.filter { !freshArticleIDs.contains($0.key) }
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
            log("FeedManager", "Failed to load from database: \(error)")
        }
    }

    public func notifyIconChange() {
        iconRevision += 1
    }

    public func decrementUnreadCount(feedID: Int64) {
        if let count = unreadCounts[feedID], count > 0 {
            unreadCounts[feedID] = count - 1
        }
    }

    /// Adjusts `unreadCounts` (and `unreadReelsCounts` for Instagram reels) by `delta`,
    /// clamping at zero. Lets `markRead`/`toggleRead` skip a full reload.
    public func adjustUnreadCount(for article: Article, delta: Int) {
        guard delta != 0 else { return }
        let current = unreadCounts[article.feedID] ?? 0
        unreadCounts[article.feedID] = max(0, current + delta)
        if article.url.contains("/reel/") {
            let currentReels = unreadReelsCounts[article.feedID] ?? 0
            unreadReelsCounts[article.feedID] = max(0, currentReels + delta)
        }
    }

    /// Applies per-feed decrement deltas in a single mutation.
    /// `reelsDecrements` is the subset of `decrements` attributable to Instagram reels,
    /// so the parallel `unreadReelsCounts` total stays aligned with `unreadCounts`.
    public func applyUnreadDecrements(_ decrements: [Int64: Int], reelsDecrements: [Int64: Int] = [:]) {
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

    public func bumpDataRevision() {
        dataRevision += 1
    }

    /// Effective unread count for `feedID` after subtracting reels when the user
    /// has the "Hide reels" Instagram setting enabled.
    public func effectiveUnreadCount(forFeedID feedID: Int64) -> Int {
        let raw = unreadCounts[feedID] ?? 0
        guard raw > 0, lastObservedHideReels else { return raw }
        let reels = unreadReelsCounts[feedID] ?? 0
        return max(0, raw - reels)
    }

}

public struct ScopedRefreshState: Hashable, Sendable {
    public var total: Int = 0
    public var completed: Int = 0
    public var refreshingFeedIDs: Set<Int64> = []
    public var pendingFeedIDs: [Int64] = []
    public var isStopping: Bool = false

    public init(
        total: Int = 0,
        completed: Int = 0,
        refreshingFeedIDs: Set<Int64> = [],
        pendingFeedIDs: [Int64] = [],
        isStopping: Bool = false
    ) {
        self.total = total
        self.completed = completed
        self.refreshingFeedIDs = refreshingFeedIDs
        self.pendingFeedIDs = pendingFeedIDs
        self.isStopping = isStopping
    }

    public var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    public var hasActiveProgress: Bool { total > 0 }
}

public enum FeedError: LocalizedError {
    case alreadyExists
    case followLimitExceeded(host: String, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists:
            String(localized: "FeedError.AlreadyExists", table: "Feeds")
        case .followLimitExceeded(let host, let limit):
            String(localized: "FeedError.FollowLimitExceeded \(host) \(limit)", table: "Feeds")
        }
    }
}
