import Foundation

/// A provider whose feeds derive from a public profile / community / playlist URL.
///
/// Conformers map between the profile URL, an opaque identifier
/// (handle, playlist ID, etc.), and the feed URL stored in the database.
/// The discovery flow calls `discoveredFeed(forProfileURL:)` to convert a
/// pasted profile URL into an addable `DiscoveredFeed`.
protocol ProfileFeedProvider: FeedProvider {

    /// The pseudo-scheme (without `://`) used in stored feed URLs.
    /// Conformers that map to a real URL (e.g. `https://note.com/<handle>/rss`)
    /// can return `nil`.
    nonisolated static var feedURLScheme: String? { get }

    /// True if `url` points to a scrapable profile / playlist page.
    nonisolated static func isProfileURL(_ url: URL) -> Bool

    /// Extracts the identifier (handle, playlist ID, etc.) from a profile URL.
    nonisolated static func extractIdentifier(from url: URL) -> String?

    /// The feed URL string stored in the database for the given identifier.
    nonisolated static func feedURL(for identifier: String) -> String

    /// True if `url` is a feed URL produced by `feedURL(for:)`.
    nonisolated static func isFeedURL(_ url: String) -> Bool

    /// Recovers the identifier from a stored feed URL, or `nil` if unrecognised.
    nonisolated static func identifierFromFeedURL(_ url: String) -> String?

    /// Constructs an addable feed from a profile URL. Conformers that
    /// need to verify reachability (e.g. RSS-backed providers where the
    /// user must opt in) should probe inside this call.
    nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed?
}

extension ProfileFeedProvider {

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isFeedURL(feedURL)
    }

    nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let scheme = feedURLScheme else { return false }
        return url.hasPrefix(scheme + "://")
    }

    nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard let scheme = feedURLScheme, isFeedURL(url) else { return nil }
        return String(url.dropFirst(scheme.count + 3))
    }
}
