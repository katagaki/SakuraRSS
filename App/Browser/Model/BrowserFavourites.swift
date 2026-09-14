import Foundation
import Observation
import Hanami

@MainActor
@Observable
final class BrowserFavourites {

    private static let storageKey = "Browser.FavouriteFeedIDs"
    private static let impliedFavouriteLimit = 8

    private(set) var feedIDs: [Int64]

    init() {
        let stored = UserDefaults.standard.array(forKey: BrowserFavourites.storageKey) as? [Int] ?? []
        feedIDs = stored.map(Int64.init)
    }

    func contains(_ feedID: Int64) -> Bool {
        feedIDs.contains(feedID)
    }

    func toggle(_ feedID: Int64) {
        if feedIDs.contains(feedID) {
            feedIDs.removeAll { $0 == feedID }
        } else {
            feedIDs.append(feedID)
        }
        persist()
    }

    /// Before the user has picked any favourites the start page would be empty,
    /// so the busiest feeds stand in until a real choice is made.
    func resolvedFeeds(feedManager: FeedManager) -> [Feed] {
        let explicit = feedIDs.compactMap { feedManager.feedsByID[$0] }
        guard explicit.isEmpty else { return explicit }
        return feedManager.feeds
            .sorted { feedManager.unreadCount(for: $0) > feedManager.unreadCount(for: $1) }
            .prefix(BrowserFavourites.impliedFavouriteLimit)
            .map { $0 }
    }

    var hasExplicitFavourites: Bool { !feedIDs.isEmpty }

    private func persist() {
        UserDefaults.standard.set(feedIDs.map(Int.init), forKey: BrowserFavourites.storageKey)
    }
}
