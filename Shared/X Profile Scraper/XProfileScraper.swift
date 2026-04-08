import Foundation
import WebKit

/// Parsed tweet from an X profile page.
struct ParsedTweet: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    /// All photo URLs when a tweet has multiple images. Empty for single-image tweets.
    let carouselImageURLs: [String]
    let publishedDate: Date?
}

/// Result of scraping an X profile: tweets and optional profile metadata.
struct XProfileScrapeResult: Sendable {
    let tweets: [ParsedTweet]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches tweets from an X (Twitter) profile using GraphQL API calls.
/// Retweets are excluded. Requires the user to be logged in via the default
/// WKWebsiteDataStore so that session cookies are available.
final class XProfileScraper {

    // swiftlint:disable line_length
    static let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

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

    /// Serialises access so only one fetch runs at a time.
    private static var activeScrape: Task<XProfileScrapeResult, Never>?

    // MARK: - Public

    /// Fetches the most recent tweets (excluding retweets) from the given profile URL.
    /// Also extracts the profile photo URL and display name.
    ///
    /// Only one fetch runs at a time; concurrent calls are serialised.
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
        // Path like /username/status/1234567890
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

    /// UserDefaults key used to cache the X session state so that
    /// it is available immediately on cold launch (before the WebKit
    /// cookie store has finished loading from disk).
    private static let xSessionCacheKey = "XProfileScraper.hasSession"

    /// Checks if the user has X cookies (i.e. is logged in).
    ///
    /// On a cold app launch the WebKit cookie store may not have
    /// finished restoring cookies from disk yet, which causes this
    /// method to incorrectly return `false`.  To work around this,
    /// we cache the result in UserDefaults and, when the cookie store
    /// returns an empty result while the cache says we were previously
    /// logged in, we retry once after a short delay to give WebKit
    /// time to load.
    @MainActor
    static func hasXSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        let found = cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("x.com") || domain.contains("twitter.com"))
                && (cookie.name == "auth_token" || cookie.name == "ct0")
        }

        if found {
            UserDefaults.standard.set(true, forKey: xSessionCacheKey)
            return true
        }

        // Cookie store returned nothing — if we were previously logged
        // in, retry once after a brief delay so WebKit can finish
        // loading cookies from disk.
        if UserDefaults.standard.bool(forKey: xSessionCacheKey) {
            try? await Task.sleep(for: .milliseconds(500))
            let retryResult = await retryHasXSession()
            UserDefaults.standard.set(retryResult, forKey: xSessionCacheKey)
            return retryResult
        }

        UserDefaults.standard.set(false, forKey: xSessionCacheKey)
        return false
    }

    /// One retry of the cookie check (no further retries to avoid loops).
    @MainActor
    private static func retryHasXSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("x.com") || domain.contains("twitter.com"))
                && (cookie.name == "auth_token" || cookie.name == "ct0")
        }
    }

    /// Clears X session cookies and cached query IDs.
    @MainActor
    static func clearXSession() async {
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
        UserDefaults.standard.set(false, forKey: xSessionCacheKey)
    }
}
