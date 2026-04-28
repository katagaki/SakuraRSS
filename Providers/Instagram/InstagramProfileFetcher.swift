import Foundation
import WebKit

struct ParsedInstagramPost: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    /// Includes the primary imageURL; empty for single-image posts.
    let carouselImageURLs: [String]
    let publishedDate: Date?
}

struct InstagramProfileFetchResult: Sendable {
    let posts: [ParsedInstagramPost]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches Instagram profile posts via the web API using Keychain-stored session cookies.
final class InstagramProfileFetcher: FetchesProfile, Authenticated {

    // `nonisolated(unsafe)` so favicon cache can raise this; only set before network calls.
    nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    static let webAppID = "936619743392459"

    static let targetPostCount = 50

    private static var activeFetch: Task<InstagramProfileFetchResult, Never>?

    nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.InstagramCookies"
    )

    // MARK: - Public

    /// Fetches the most recent posts plus profile metadata. Concurrent calls are serialised.
    func fetchProfile(profileURL: URL) async -> InstagramProfileFetchResult {
        if let existing = Self.activeFetch {
            _ = await existing.value
        }

        let task = Task {
            await self.performFetch(profileURL: profileURL)
        }
        Self.activeFetch = task
        let result = await task.value
        Self.activeFetch = nil
        return result
    }

    // MARK: - Static Helpers

    nonisolated static func isInstagramHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "instagram.com" || host == "www.instagram.com"
    }

    nonisolated static func isInstagramPostURL(_ url: URL) -> Bool {
        guard isInstagramHost(url.host) else { return false }
        let components = url.pathComponents
        return components.count >= 3
            && (components[1] == "p" || components[1] == "reel")
    }

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://www.instagram.com/\(handle)/")
    }
}

// MARK: - FetchesProfile

extension InstagramProfileFetcher {

    nonisolated static var feedURLScheme: String? { "instagram-profile" }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isInstagramHost(url.host) else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "explore", "accounts", "p", "reel", "reels", "stories",
            "direct", "about", "legal", "developer", "api",
            "static", "emails", "challenge", "nux", "graphql"
        ]
        return !reserved.contains(handle.lowercased())
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "instagram-profile://\(identifier.lowercased())"
    }
}

// MARK: - Authenticated

extension InstagramProfileFetcher {

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain.contains("instagram.com")
    }

    nonisolated static var sessionCookieNames: Set<String>? { ["sessionid", "ds_user_id"] }

    nonisolated static var cookieWarmURL: URL? {
        URL(string: "https://www.instagram.com/")
    }
}
