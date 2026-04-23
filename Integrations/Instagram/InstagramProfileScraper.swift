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

struct InstagramProfileScrapeResult: Sendable {
    let posts: [ParsedInstagramPost]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches Instagram profile posts via the web API using Keychain-stored session cookies.
final class InstagramProfileScraper {

    // `nonisolated(unsafe)` so favicon cache can raise this; only set before network calls.
    nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    static let webAppID = "936619743392459"

    static let targetPostCount = 50

    private static var activeScrape: Task<InstagramProfileScrapeResult, Never>?

    static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.InstagramCookies"
    )

    // MARK: - Public

    /// Fetches the most recent posts plus profile metadata. Concurrent calls are serialised.
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

    nonisolated static func isInstagramPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isInstagramDomain = host == "instagram.com" || host == "www.instagram.com"
        guard isInstagramDomain else { return false }
        let components = url.pathComponents
        return components.count >= 3
            && (components[1] == "p" || components[1] == "reel")
    }

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

    nonisolated static func extractHandle(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://www.instagram.com/\(handle)/")
    }

    nonisolated static func feedURL(for handle: String) -> String {
        "instagram-profile://\(handle.lowercased())"
    }

    nonisolated static func isInstagramFeedURL(_ url: String) -> Bool {
        url.hasPrefix("instagram-profile://")
    }

    nonisolated static func handleFromFeedURL(_ url: String) -> String? {
        guard isInstagramFeedURL(url) else { return nil }
        return String(url.dropFirst("instagram-profile://".count))
    }

    // `async` is kept for API stability with the old WebKit-backed implementation.
    static func hasInstagramSession() async -> Bool {
        guard let cookies = cookieStore.load() else { return false }
        return cookies.contains { cookie in
            cookie.name == "sessionid" || cookie.name == "ds_user_id"
        }
    }

    /// Clears Instagram cookies from Keychain and the WebKit data store.
    @MainActor
    static func clearInstagramSession() async {
        cookieStore.clear()

        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("instagram.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
    }

    /// Exports Instagram cookies from `WKWebsiteDataStore` into Keychain after login.
    @MainActor
    static func syncCookiesFromWebKit() async {
        let store = WKWebsiteDataStore.default()
        let allCookies = await store.httpCookieStore.allCookies()
        let instagramCookies = allCookies.filter {
            $0.domain.lowercased().contains("instagram.com")
        }
        guard !instagramCookies.isEmpty else { return }
        cookieStore.save(instagramCookies)

        #if DEBUG
        print("[InstagramProfileScraper] Synced \(instagramCookies.count) "
              + "cookies from WebKit → Keychain")
        #endif
    }

    /// One-time migration from WebKit-only storage to Keychain. Safe to call repeatedly.
    @MainActor
    static func migrateWebKitCookiesIfNeeded() async {
        if cookieStore.load() != nil { return }

        // Force WebKit to restore its on-disk cookie store before inspection -
        // on a cold launch `allCookies()` returns empty until a WKWebView loads the domain.
        await warmCookieStore()
        await syncCookiesFromWebKit()
    }
}
