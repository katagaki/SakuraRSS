import Foundation

/// Static, stateless metadata about a feed source whose URLs and refresh
/// behaviour the app handles specially (X, Reddit, YouTube playlists, etc.).
///
/// Conformers describe how to recognise their feed URLs so that
/// `FeedProviderRegistry` can dispatch URL routing without per-call-site
/// `if-else` chains.
protocol FeedProvider {

    /// Stable, lowercased provider identifier (e.g. `"x"`, `"reddit"`).
    nonisolated static var providerID: String { get }

    /// `UserDefaults` Bool key gating the provider; `nil` if always on.
    nonisolated static var labsFlagKey: String? { get }

    /// True if `feedURL` (as stored in the database) belongs to this provider.
    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool
}

extension FeedProvider {

    nonisolated static var labsFlagKey: String? { nil }

    /// True if the provider is enabled (no flag, or its flag is on).
    nonisolated static var isEnabled: Bool {
        guard let key = labsFlagKey else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}
