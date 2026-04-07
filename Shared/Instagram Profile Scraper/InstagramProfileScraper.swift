import Foundation
import WebKit

/// Parsed post from an Instagram profile.
struct ParsedInstagramPost: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    let publishedDate: Date?
}

/// Result of scraping an Instagram profile: posts and optional profile metadata.
struct InstagramProfileScrapeResult: Sendable {
    let posts: [ParsedInstagramPost]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches posts from an Instagram profile using the web API.
/// Requires the user to be logged in via the default WKWebsiteDataStore
/// so that session cookies are available.
final class InstagramProfileScraper {

    // swiftlint:disable line_length
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
    // swiftlint:enable line_length

    static let targetPostCount = 50

    /// Serialises access so only one fetch runs at a time.
    private static var activeScrape: Task<InstagramProfileScrapeResult, Never>?

    // MARK: - Public

    /// Fetches the most recent posts from the given profile URL.
    /// Also extracts the profile photo URL and display name.
    ///
    /// Only one fetch runs at a time; concurrent calls are serialised.
    func scrapeProfile(profileURL: URL) async -> InstagramProfileScrapeResult {
        if let existing = Self.activeScrape {
            _ = await existing.value
        }

        let task = Task {
            await self.performFetch(profileURL: profileURL)
        }
        Self.activeScrape = task
        let result = await task.value
        Self.activeScrape = nil
        return result
    }

    // MARK: - Static Helpers

    /// Returns true if the URL points to a specific Instagram post.
    nonisolated static func isInstagramPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isInstagramDomain = host == "instagram.com" || host == "www.instagram.com"
        guard isInstagramDomain else { return false }
        let components = url.pathComponents
        // /p/SHORTCODE/ or /reel/SHORTCODE/
        return components.count >= 3
            && (components[1] == "p" || components[1] == "reel")
    }

    /// Returns true if the URL points to an Instagram profile.
    nonisolated static func isInstagramProfileURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isInstagramDomain = host == "instagram.com" || host == "www.instagram.com"
        guard isInstagramDomain else { return false }

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

    /// Extracts the username handle from an Instagram profile URL.
    nonisolated static func extractHandle(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    /// Constructs a canonical Instagram profile URL from a handle.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://www.instagram.com/\(handle)/")
    }

    /// The pseudo-feed URL stored in the database for an Instagram profile.
    nonisolated static func feedURL(for handle: String) -> String {
        "instagram-profile://\(handle.lowercased())"
    }

    /// Checks if a feed URL is an Instagram pseudo-feed.
    nonisolated static func isInstagramFeedURL(_ url: String) -> Bool {
        url.hasPrefix("instagram-profile://")
    }

    /// Extracts the handle from an Instagram pseudo-feed URL.
    nonisolated static func handleFromFeedURL(_ url: String) -> String? {
        guard isInstagramFeedURL(url) else { return nil }
        return String(url.dropFirst("instagram-profile://".count))
    }

    /// UserDefaults key used to cache the Instagram session state.
    private static let sessionCacheKey = "InstagramProfileScraper.hasSession"

    /// Checks if the user has Instagram cookies (i.e. is logged in).
    @MainActor
    static func hasInstagramSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        let found = cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return domain.contains("instagram.com")
                && (cookie.name == "sessionid" || cookie.name == "ds_user_id")
        }

        if found {
            UserDefaults.standard.set(true, forKey: sessionCacheKey)
            return true
        }

        // Cookie store may not have finished loading — retry if we were
        // previously logged in.
        if UserDefaults.standard.bool(forKey: sessionCacheKey) {
            try? await Task.sleep(for: .milliseconds(500))
            let retryResult = await retryHasInstagramSession()
            UserDefaults.standard.set(retryResult, forKey: sessionCacheKey)
            return retryResult
        }

        UserDefaults.standard.set(false, forKey: sessionCacheKey)
        return false
    }

    /// One retry of the cookie check.
    @MainActor
    private static func retryHasInstagramSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return domain.contains("instagram.com")
                && (cookie.name == "sessionid" || cookie.name == "ds_user_id")
        }
    }

    /// Clears Instagram session cookies.
    @MainActor
    static func clearInstagramSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("instagram.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
        UserDefaults.standard.set(false, forKey: sessionCacheKey)
    }
}
