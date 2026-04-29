import Foundation

/// A fetcher that maps between a public profile URL, an opaque identifier
/// (handle, playlist ID, etc.), and the pseudo-feed URL stored in the database.
///
/// Conformers declare the matching pieces (`feedURLScheme`, `isProfileURL`,
/// `extractIdentifier`, `feedURL(for:)`); the protocol provides the round-trip
/// helpers (`isFeedURL`, `identifierFromFeedURL`) by default.
protocol ProfileFetcher {

    /// The pseudo-scheme (without `://`) used in stored feed URLs, e.g.
    /// `"x-profile"`, `"instagram-profile"`, `"youtube-playlist"`. Conformers
    /// that map to a real URL (e.g. note.com RSS) can return `nil`.
    nonisolated static var feedURLScheme: String? { get }

    /// True if `url` points to a scrapable profile/playlist page.
    nonisolated static func isProfileURL(_ url: URL) -> Bool

    /// Extracts the identifier (handle, playlist ID, etc.) from a profile URL.
    nonisolated static func extractIdentifier(from url: URL) -> String?

    /// The pseudo-feed URL string stored in the database for the given identifier.
    nonisolated static func feedURL(for identifier: String) -> String

    /// True if `url` is a feed URL produced by `feedURL(for:)`.
    nonisolated static func isFeedURL(_ url: String) -> Bool

    /// Recovers the identifier from a stored feed URL, or `nil` if unrecognised.
    nonisolated static func identifierFromFeedURL(_ url: String) -> String?
}

extension ProfileFetcher {

    nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let scheme = feedURLScheme else { return false }
        return url.hasPrefix(scheme + "://")
    }

    nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard let scheme = feedURLScheme, isFeedURL(url) else { return nil }
        return String(url.dropFirst(scheme.count + 3))
    }
}
