import Foundation
import WebKit

struct ParsedTweet: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    let carouselImageURLs: [String]
    let publishedDate: Date?
}

struct XProfileScrapeResult: Sendable {
    let tweets: [ParsedTweet]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches tweets from an X (Twitter) profile using GraphQL API calls.
final class XProfileScraper {

    nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    // swiftlint:disable line_length
    static let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    static var userByScreenNameQueryID: String?
    static var userTweetsQueryID: String?
    static var tweetDetailQueryID: String?

    static let userByScreenNameFeatures: [String: Bool] = [
        "hidden_profile_subscriptions_enabled": true,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": false,
        "verified_phone_label_enabled": false,
        "subscriptions_verification_info_is_identity_verified_enabled": true,
        "subscriptions_verification_info_verified_since_enabled": true,
        "highlights_tweets_tab_ui_enabled": true,
        "responsive_web_twitter_article_notes_tab_enabled": true,
        "subscriptions_feature_can_gift_premium": true,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "responsive_web_graphql_timeline_navigation_enabled": true
    ]

    // swiftlint:enable line_length

    static let targetTweetCount = 50

    /// Keychain-backed persistent cookie jar.
    static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.XCookies"
    )

    /// Serialises access so only one fetch runs at a time.
    private static var activeScrape: Task<XProfileScrapeResult, Never>?

    // MARK: - Public

    /// Fetches recent tweets (no retweets), profile photo and display name.
    /// Serialised: only one fetch runs at a time.
    func scrapeProfile(profileURL: URL) async -> XProfileScrapeResult {
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

    @MainActor
    static var queryIDsFetched = false

    // MARK: - Static Helpers

    /// Returns true if the URL points to a specific X/Twitter post (status).
    nonisolated static func isXPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isXDomain = host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
        guard isXDomain else { return false }
        let components = url.pathComponents
        return components.count >= 4 && components[2] == "status"
    }

    /// Extracts the tweet ID from an X/Twitter status URL.
    nonisolated static func extractTweetID(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count >= 4, components[2] == "status" else { return nil }
        return components[3]
    }

    /// Returns true if the URL points to an X/Twitter profile.
    nonisolated static func isXProfileURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isXDomain = host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
        guard isXDomain else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "home", "explore", "search", "notifications", "messages",
            "settings", "login", "signup", "i", "intent", "hashtag",
            "compose", "tos", "privacy"
        ]
        return !reserved.contains(handle.lowercased())
    }

    /// Extracts the username handle from an X profile URL.
    nonisolated static func extractHandle(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    /// Constructs a canonical X profile URL from a handle.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://x.com/\(handle)")
    }

    /// The pseudo-feed URL stored in the database for an X profile.
    nonisolated static func feedURL(for handle: String) -> String {
        "x-profile://\(handle.lowercased())"
    }

    /// Checks if a feed URL is an X pseudo-feed.
    nonisolated static func isXFeedURL(_ url: String) -> Bool {
        url.hasPrefix("x-profile://")
    }

    /// Extracts the handle from an X pseudo-feed URL.
    nonisolated static func handleFromFeedURL(_ url: String) -> String? {
        guard isXFeedURL(url) else { return nil }
        return String(url.dropFirst("x-profile://".count))
    }

    /// Checks if the user has X cookies (i.e. is logged in).
    static func hasXSession() async -> Bool {
        guard let cookies = cookieStore.load() else { return false }
        return cookies.contains { cookie in
            cookie.name == "auth_token" || cookie.name == "ct0"
        }
    }

    /// Clears X session cookies (Keychain + WebKit) and cached query IDs.
    @MainActor
    static func clearXSession() async {
        cookieStore.clear()

        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("x.com")
            || cookie.domain.lowercased().contains("twitter.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
        userByScreenNameQueryID = nil
        userTweetsQueryID = nil
        tweetDetailQueryID = nil
        queryIDsFetched = false
    }

    /// Exports X cookies from WKWebsiteDataStore to Keychain after login.
    @MainActor
    static func syncCookiesFromWebKit() async {
        let store = WKWebsiteDataStore.default()
        let allCookies = await store.httpCookieStore.allCookies()
        let xCookies = allCookies.filter {
            let domain = $0.domain.lowercased()
            return domain.contains("x.com") || domain.contains("twitter.com")
        }
        guard !xCookies.isEmpty else { return }
        cookieStore.save(xCookies)

        #if DEBUG
        print("[XProfileScraper] Synced \(xCookies.count) "
              + "cookies from WebKit → Keychain")
        #endif
    }

    /// Migrates cookies from WebKit to Keychain once for users upgrading from older builds.
    @MainActor
    static func migrateWebKitCookiesIfNeeded() async {
        if cookieStore.load() != nil { return }

        await warmCookieStore()
        await syncCookiesFromWebKit()
    }
}
