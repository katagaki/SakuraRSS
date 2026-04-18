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
    /// All image URLs for carousel posts (includes the primary imageURL).
    /// Empty for single-image posts.
    let carouselImageURLs: [String]
    let publishedDate: Date?
}

/// Result of scraping an Instagram profile: posts and optional profile metadata.
struct InstagramProfileScrapeResult: Sendable {
    let posts: [ParsedInstagramPost]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches posts from an Instagram profile using the web API.
///
/// Session cookies are kept in a Keychain-backed store (`cookieStore`)
/// populated from the login WebView on success and, for users upgrading
/// from older builds, by a one-time migration from `WKWebsiteDataStore`.
final class InstagramProfileScraper {

    /// Per-request timeout used for every URLRequest this scraper builds.
    /// Callers that perform cosmetic work (e.g. favicon avatar lookups)
    /// can raise this value to effectively bypass the normal timeout.
    /// Marked `nonisolated(unsafe)` so it can be configured from the
    /// favicon cache's nonisolated avatar-fetching methods; the value
    /// is only ever set before network calls start, so there is no
    /// meaningful data race.
    nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    // swiftlint:disable line_length

    /// Instagram's web application ID, embedded in their JS bundle.
    static let webAppID = "936619743392459"

    static let targetPostCount = 50

    /// Serialises access so only one fetch runs at a time.
    private static var activeScrape: Task<InstagramProfileScrapeResult, Never>?

    static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.InstagramCookies"
    )

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

    /// Checks if the user has Instagram cookies (i.e. is logged in).
    ///
    /// Kept `async` for API stability with the old WebKit-backed
    /// implementation; the body is a synchronous Keychain read.
    static func hasInstagramSession() async -> Bool {
        guard let cookies = cookieStore.load() else { return false }
        return cookies.contains { cookie in
            cookie.name == "sessionid" || cookie.name == "ds_user_id"
        }
    }

    /// Clears Instagram session cookies from both Keychain and the
    /// WebKit data store (so the login WebView starts fresh).
    @MainActor
    static func clearInstagramSession() async {
        cookieStore.clear()

        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("instagram.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
    }

    /// Exports any Instagram cookies present in the default
    /// `WKWebsiteDataStore` into Keychain.  Called after the user
    /// completes the login flow in `InstagramLoginView` so that the
    /// scraper's Keychain-backed session check can find them.
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

    /// One-time migration for users upgrading from the WebKit-only
    /// storage model.  If Keychain is empty but the WebKit data store
    /// holds Instagram cookies from a prior install, copy them over so
    /// the user stays signed in without having to log in again.
    ///
    /// Safe to call repeatedly - the Keychain-empty check makes it a
    /// no-op after the first successful migration.
    @MainActor
    static func migrateWebKitCookiesIfNeeded() async {
        // Fast path: already migrated.
        if cookieStore.load() != nil { return }

        // Force WebKit to restore its on-disk cookie store before we
        // inspect it - on a cold launch `allCookies()` returns an empty
        // array until a WKWebView has loaded a page from the domain.
        await warmCookieStore()
        await syncCookiesFromWebKit()
    }
}
