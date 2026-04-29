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

struct XProfileFetchResult: Sendable {
    let tweets: [ParsedTweet]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches tweets from an X (Twitter) profile using GraphQL API calls.
final class XProfileFetcher: ProfileFetcher, Authenticated {

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
    nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.XCookies"
    )

    /// Serialises access so only one fetch runs at a time.
    private static var activeFetch: Task<XProfileFetchResult, Never>?

    // MARK: - Public

    /// Fetches recent tweets (no retweets), profile photo and display name.
    /// Serialised: only one fetch runs at a time.
    func fetchProfile(profileURL: URL) async -> XProfileFetchResult {
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

    @MainActor
    static var queryIDsFetched = false

    // MARK: - Static Helpers

    /// Returns true if `host` belongs to x.com / twitter.com (incl. www, mobile).
    nonisolated static func isXHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
    }

    /// Returns true if the URL points to a specific X/Twitter post (status).
    nonisolated static func isXPostURL(_ url: URL) -> Bool {
        guard isXHost(url.host) else { return false }
        let components = url.pathComponents
        return components.count >= 4 && components[2] == "status"
    }

    /// Extracts the tweet ID from an X/Twitter status URL.
    nonisolated static func extractTweetID(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count >= 4, components[2] == "status" else { return nil }
        return components[3]
    }

    /// Constructs a canonical X profile URL from a handle.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://x.com/\(handle)")
    }

    @MainActor
    static func didClearSession() async {
        userByScreenNameQueryID = nil
        userTweetsQueryID = nil
        tweetDetailQueryID = nil
        queryIDsFetched = false
    }
}

// MARK: - ProfileFetcher

extension XProfileFetcher {

    nonisolated static var feedURLScheme: String? { "x-profile" }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isXHost(url.host) else { return false }

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

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "x-profile://\(identifier.lowercased())"
    }
}

// MARK: - Authenticated

extension XProfileFetcher {

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain.contains("x.com") || domain.contains("twitter.com")
    }

    nonisolated static var sessionCookieNames: Set<String>? { ["auth_token", "ct0"] }

    nonisolated static var cookieWarmURL: URL? {
        URL(string: "https://x.com/settings")
    }
}
