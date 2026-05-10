import Foundation
import WebKit

/// Fetches tweets from an X (Twitter) profile using GraphQL API calls.
public final class XProvider: Authenticated {

    public init() {}

    public nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    // swiftlint:disable line_length
    public static let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    public static var userByScreenNameQueryID: String?
    public static var userTweetsQueryID: String?
    public static var tweetDetailQueryID: String?
    public static var tweetResultByRestIdQueryID: String?

    public static let userByScreenNameFeatures: [String: Bool] = [
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

    public static let targetTweetCount = 50

    /// Keychain-backed persistent cookie jar.
    public nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.XCookies"
    )

    /// Serialises access so only one fetch runs at a time.
    private static var activeFetch: Task<XProfileFetchResult, Never>?
    /// Fetches recent tweets (no retweets), profile photo and display name.
    /// Serialised: only one fetch runs at a time.
    public func fetchProfile(
        profileURL: URL,
        autoRepairQueryIDs: Bool = true
    ) async -> XProfileFetchResult {
        if let existing = Self.activeFetch {
            _ = await existing.value
        }

        let task = Task {
            await self.performFetch(
                profileURL: profileURL,
                autoRepairQueryIDs: autoRepairQueryIDs
            )
        }
        Self.activeFetch = task
        let result = await task.value
        Self.activeFetch = nil
        return result
    }

    @MainActor
    public static var queryIDsFetched = false
    /// Returns true if `host` belongs to x.com / twitter.com (incl. www, mobile).
    /// Stricter than `matchesHost` because X feeds aren't reachable on
    /// arbitrary subdomains.
    public nonisolated static func isXHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
    }

    /// Returns true if the URL points to a specific X/Twitter post (status).
    public nonisolated static func isXPostURL(_ url: URL) -> Bool {
        guard isXHost(url.host) else { return false }
        let components = url.pathComponents
        return components.count >= 4 && components[2] == "status"
    }

    /// Extracts the tweet ID from an X/Twitter status URL.
    public nonisolated static func extractTweetID(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count >= 4, components[2] == "status" else { return nil }
        return components[3]
    }

    /// Constructs a canonical X profile URL from a handle.
    public nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://x.com/\(handle)")
    }

    @MainActor
    public static func didClearSession() async {
        userByScreenNameQueryID = nil
        userTweetsQueryID = nil
        tweetDetailQueryID = nil
        tweetResultByRestIdQueryID = nil
        queryIDsFetched = false
    }
}
