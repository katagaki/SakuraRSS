import Foundation

struct BlueskyProfileFetchResult: Sendable {
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches Bluesky profile metadata by scraping the public profile page.
final class BlueskyProfileFetcher: ProfileFetcher {

    nonisolated static let host = "bsky.app"

    nonisolated static let reservedHandles: Set<String> = [
        "search", "notifications", "settings", "feeds", "lists",
        "messages", "starter-pack", "starter-pack-short",
        "hashtag", "support", "intent"
    ]

    // MARK: - ProfileFetcher

    nonisolated static var feedURLScheme: String? { nil }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isBlueskyHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2,
              components[0].lowercased() == "profile" else { return false }
        return isValidHandle(components[1])
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard isBlueskyHost(url.host) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2,
              components[0].lowercased() == "profile",
              isValidHandle(components[1]) else { return nil }
        return components[1]
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "https://bsky.app/profile/\(identifier)/rss"
    }

    nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let parsed = URL(string: url),
              isBlueskyHost(parsed.host) else { return false }
        let components = parsed.pathComponents.filter { $0 != "/" }
        guard components.count == 3,
              components[0].lowercased() == "profile",
              components.last?.lowercased() == "rss" else { return false }
        return isValidHandle(components[1])
    }

    nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard isFeedURL(url),
              let parsed = URL(string: url) else { return nil }
        let components = parsed.pathComponents.filter { $0 != "/" }
        return components.count >= 2 ? components[1] : nil
    }

    // MARK: - Static Helpers

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://bsky.app/profile/\(handle)")
    }

    private nonisolated static func isBlueskyHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == Self.host || host.hasSuffix(".\(Self.host)")
    }

    private nonisolated static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return false }
        return !reservedHandles.contains(handle.lowercased())
    }

    // MARK: - Public

    func fetchProfile(handle: String) async -> BlueskyProfileFetchResult {
        await performFetch(handle: handle)
    }
}
