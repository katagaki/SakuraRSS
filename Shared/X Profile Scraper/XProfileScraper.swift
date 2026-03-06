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
    let publishedDate: Date?
}

/// Result of scraping an X profile: tweets and optional profile metadata.
struct XProfileScrapeResult: Sendable {
    let tweets: [ParsedTweet]
    let profileImageURL: String?
    let displayName: String?
}

/// Scrapes tweets from an X (Twitter) profile using a headless WKWebView.
/// Retweets are excluded. Requires the user to be logged in via the default
/// WKWebsiteDataStore so that session cookies are available.
@MainActor
final class XProfileScraper: NSObject, WKNavigationDelegate {

    private static let targetTweetCount = 50
    private static let maxScrollAttempts = 15
    /// Maximum consecutive scrolls that yield zero new tweets before giving up.
    private static let maxStaleScrolls = 3
    /// Polling interval when waiting for content to appear.
    private static let pollInterval: Duration = .milliseconds(500)
    /// Maximum time to wait for the initial tweet elements to appear.
    private static let renderTimeout: Duration = .seconds(8)
    /// Maximum time to wait for new tweets after a scroll.
    private static let scrollSettleTimeout: Duration = .seconds(4)

    private var webView: WKWebView?

    /// Serialises access so only one scrape runs at a time, avoiding multiple
    /// concurrent WKWebViews on the main actor.
    private static var activeScrape: Task<XProfileScrapeResult, Never>?

    // MARK: - Public

    /// Scrapes the most recent tweets (excluding retweets) from the given profile URL.
    /// Scrolls the page repeatedly to load at least 50 tweets.
    /// Also extracts the profile photo URL.
    ///
    /// Only one scrape runs at a time; concurrent calls are serialised.
    func scrapeProfile(profileURL: URL) async -> XProfileScrapeResult {
        // Wait for any in-flight scrape to finish before starting ours.
        if let existing = Self.activeScrape {
            _ = await existing.value
        }

        let task = Task { @MainActor in
            await self.performScrape(profileURL: profileURL)
        }
        Self.activeScrape = task
        let result = await task.value
        Self.activeScrape = nil
        return result
    }

    private func performScrape(profileURL: URL) async -> XProfileScrapeResult {
        let webView = createWebView()
        self.webView = webView
        await installContentBlocker(on: webView)

        let loaded = await loadPage(webView: webView, url: profileURL)
        guard loaded else {
            cleanup()
            return XProfileScrapeResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        // Poll for tweet elements instead of a fixed sleep.
        let tweetsAppeared = await waitForSelector(
            "article[data-testid=\"tweet\"]",
            in: webView,
            timeout: Self.renderTimeout
        )
        guard tweetsAppeared, !Task.isCancelled else {
            cleanup()
            return XProfileScrapeResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        // Wait for the profile avatar to load, then extract before scrolling.
        _ = await waitForSelector(
            "img[src*=\"profile_images\"]",
            in: webView,
            timeout: Self.renderTimeout
        )
        let profileImageURL = await extractProfileImageURL(from: webView)
        let displayName = await extractDisplayName(from: webView)

        let allTweets = await scrollAndCollectTweets(from: webView)

        cleanup()
        return XProfileScrapeResult(tweets: allTweets, profileImageURL: profileImageURL, displayName: displayName)
    }

    /// Scrolls the page and collects tweets until we have enough or no new content appears.
    private func scrollAndCollectTweets(from webView: WKWebView) async -> [ParsedTweet] {
        var allTweets: [ParsedTweet] = []
        var seenURLs = Set<String>()
        var staleScrolls = 0

        for _ in 0..<Self.maxScrollAttempts {
            guard !Task.isCancelled else { break }

            let batch = await extractCurrentTweets(from: webView)
            var newCount = 0
            for tweet in batch where !seenURLs.contains(tweet.url) {
                seenURLs.insert(tweet.url)
                allTweets.append(tweet)
                newCount += 1
            }

            if allTweets.count >= Self.targetTweetCount { break }

            if newCount == 0 {
                staleScrolls += 1
                if staleScrolls >= Self.maxStaleScrolls { break }
            } else {
                staleScrolls = 0
            }

            let domCountBefore = await tweetDOMCount(in: webView)
            await scrollToBottom(webView: webView)

            await waitForNewContent(
                currentCount: domCountBefore,
                in: webView,
                timeout: Self.scrollSettleTimeout
            )
        }

        return allTweets
    }

    // MARK: - Page Loading

    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 430, height: 932),
            configuration: config
        )
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        return webView
    }

    /// Installs content rules that block heavy media (video, streaming) to speed
    /// up page loading. Called after createWebView so it can be async.
    private func installContentBlocker(on webView: WKWebView) async {
        // Block video/streaming but not images (needed for tweet/profile image extraction).
        let blockRules = """
        [
            {"trigger":{"url-filter":".*","resource-type":["media","popup"]},
             "action":{"type":"block"}},
            {"trigger":{"url-filter":".*\\\\.mp4"},
             "action":{"type":"block"}},
            {"trigger":{"url-filter":".*\\\\.m3u8"},
             "action":{"type":"block"}}
        ]
        """
        do {
            let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "XProfileScraper.blockMedia",
                encodedContentRuleList: blockRules
            )
            if let ruleList {
                webView.configuration.userContentController.add(ruleList)
            }
        } catch {
            // Content blocking is best-effort; scraping works without it.
        }
    }

    private func loadPage(webView: WKWebView, url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            let delegate = XProfileNavigationHandler(continuation: continuation)
            webView.navigationDelegate = delegate
            // Prevent delegate from being deallocated before callback fires
            objc_setAssociatedObject(webView, "navDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.load(URLRequest(url: url, timeoutInterval: 15))
        }
    }

    private func scrollToBottom(webView: WKWebView) async {
        _ = try? await webView.evaluateJavaScript(
            "window.scrollTo(0, document.body.scrollHeight)"
        )
    }

    // MARK: - Smart Waiting

    /// Polls until the given CSS selector matches at least one element.
    private func waitForSelector(
        _ selector: String,
        in webView: WKWebView,
        timeout: Duration
    ) async -> Bool {
        let script = "document.querySelector('\(selector)') !== null"
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if Task.isCancelled { return false }
            if let found = try? await webView.evaluateJavaScript(script) as? Bool, found {
                return true
            }
            try? await Task.sleep(for: Self.pollInterval)
        }
        return false
    }

    /// Returns the current number of tweet article elements in the DOM.
    private func tweetDOMCount(in webView: WKWebView) async -> Int {
        let script = "document.querySelectorAll('article[data-testid=\"tweet\"]').length"
        return (try? await webView.evaluateJavaScript(script) as? Int) ?? 0
    }

    /// Polls until the number of visible tweet articles exceeds `currentCount`.
    private func waitForNewContent(
        currentCount: Int,
        in webView: WKWebView,
        timeout: Duration
    ) async {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if Task.isCancelled { return }
            if await tweetDOMCount(in: webView) > currentCount { return }
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    // MARK: - Static Helpers

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
    /// Uses a custom scheme prefix so we can distinguish X feeds from real RSS feeds.
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
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("x.com") || domain.contains("twitter.com"))
                && (cookie.name == "auth_token" || cookie.name == "ct0")
        }
    }

    /// Clears X session cookies.
    static func clearXSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("x.com")
            || cookie.domain.lowercased().contains("twitter.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeAllContentRuleLists()
        webView = nil
    }
}
