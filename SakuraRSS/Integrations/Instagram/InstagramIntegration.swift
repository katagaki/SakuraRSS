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
/// Requires the user to be logged in via the default WKWebsiteDataStore
/// so that session cookies are available.
final class InstagramIntegration: Integration {

    // swiftlint:disable line_length

    /// Instagram's web application ID, embedded in their JS bundle.
    static let webAppID = "936619743392459"

    static let targetPostCount = 50

    /// Serialises access so only one fetch runs at a time.
    private static var activeScrape: Task<InstagramProfileScrapeResult, Never>?

    // MARK: - Integration overrides

    nonisolated override class var feedURLScheme: String { InstagramURLHelpers.feedURLScheme }

    nonisolated override class var requiresAuthentication: Bool { true }

    nonisolated override class var supportsProfilePhoto: Bool { true }

    @MainActor
    override class func hasSession() async -> Bool {
        await hasInstagramSession()
    }

    @MainActor
    override class func clearSession() async {
        await clearInstagramSession()
    }

    /// Resolves an Instagram handle to its profile image URL. Instagram's
    /// `web_profile_info` endpoint returns both the profile metadata and
    /// the first page of posts in a single request, so there's no way to
    /// ask for the avatar alone — we just discard the posts.
    override func profileImageURL(forIdentifier identifier: String) async -> String? {
        guard let profileURL = InstagramURLHelpers.profileURL(for: identifier) else {
            return nil
        }
        let result = await scrapeProfile(profileURL: profileURL)
        return result.profileImageURL
    }

    override func scrape(identifier: String) async -> IntegrationScrapeResult {
        guard let profileURL = InstagramURLHelpers.profileURL(for: identifier) else {
            return IntegrationScrapeResult()
        }

        let result = await scrapeProfile(profileURL: profileURL)

        let articles = result.posts.map { post -> ArticleInsertItem in
            let title = post.text.isEmpty
                ? "Post by @\(post.authorHandle)"
                : String(post.text.prefix(200))
            return ArticleInsertItem(
                title: title,
                url: post.url,
                data: ArticleInsertData(
                    author: post.author.isEmpty ? "@\(post.authorHandle)" : post.author,
                    summary: post.text.isEmpty ? nil : post.text,
                    imageURL: post.imageURL,
                    carouselImageURLs: post.carouselImageURLs,
                    publishedDate: post.publishedDate
                )
            )
        }

        return IntegrationScrapeResult(
            articles: articles,
            feedTitle: result.displayName,
            profileImageURL: result.profileImageURL
        )
    }

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

    // MARK: - Session

    /// UserDefaults key used to cache the Instagram session state.
    private static let sessionCacheKey = "InstagramIntegration.hasSession"

    /// Checks if the user has Instagram cookies (i.e. is logged in).
    @MainActor
    static func hasInstagramSession() async -> Bool {
        // Ensure the WKWebsiteDataStore has restored persisted cookies from
        // disk before we inspect them. On cold launch, allCookies() returns
        // an empty array until a WKWebView has loaded a page from the
        // domain, which makes the user look logged-out even when they aren't.
        await warmCookieStore()

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

        // Cookie store may still not have finished loading — retry if we were
        // previously logged in.
        if UserDefaults.standard.bool(forKey: sessionCacheKey) {
            try? await Task.sleep(for: .milliseconds(500))
            let retryResult = await retryHasInstagramSession()
            if retryResult {
                return true
            }
            // Don't clear the cache here — a transient cookie-store miss
            // shouldn't silently sign the user out. clearInstagramSession()
            // is the only path that should flip this to false.
            return false
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

    // swiftlint:enable line_length
}
