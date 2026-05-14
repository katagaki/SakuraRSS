import Foundation

/// A feed source with stable identity and feed-URL recognition.
public protocol FeedProvider {

    nonisolated static var providerID: String { get }

    /// `UserDefaults` Bool key gating the provider; `nil` if always on.
    nonisolated static var enabledFlagKey: String? { get }

    /// Lowercased canonical hostnames this provider claims responsibility for.
    /// `matchesHost(_:)` accepts these and any subdomain. Providers that need
    /// stricter subdomain rules can narrow further in their own predicates.
    nonisolated static var domains: Set<String> { get }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool

    /// Reconstructs a human-facing site URL from a stored feed URL, when the
    /// mapping is unambiguous (e.g. `…/r/swift/.rss` → `https://www.reddit.com/r/swift`).
    /// Returns `nil` if the provider can't derive one. Used to backfill siteURL
    /// when OPML imports omit `htmlUrl`.
    nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String?
}

public extension FeedProvider {

    nonisolated static var enabledFlagKey: String? { nil }

    nonisolated static var isEnabled: Bool {
        guard let key = enabledFlagKey else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// True when `host` equals one of `domains` or is a subdomain of it.
    nonisolated static func matchesHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    nonisolated static func inferredSiteURL(fromFeedURL _: String) -> String? { nil }
}
