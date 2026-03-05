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

/// Scrapes tweets from an X (Twitter) profile using a headless WKWebView.
/// Retweets are excluded. Requires the user to be logged in via the default
/// WKWebsiteDataStore so that session cookies are available.
@MainActor
final class XProfileScraper: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<[ParsedTweet], Never>?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Public

    /// Scrapes the most recent tweets (excluding retweets) from the given profile URL.
    func scrapeTweets(profileURL: URL) async -> [ParsedTweet] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 430, height: 932), configuration: config)
            webView.navigationDelegate = self
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
            self.webView = webView

            webView.load(URLRequest(url: profileURL))

            self.timeoutTask = Task {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                self.finishWithTimeout()
            }
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

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.timeoutTask?.cancel()
            self.timeoutTask = nil
            // Wait for JS SPA to render tweets
            try? await Task.sleep(for: .seconds(4))
            self.extractTweets()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finishWithResult([])
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finishWithResult([])
        }
    }

    // MARK: - Extraction

    /// JavaScript that extracts tweets from the rendered X profile page.
    /// Excludes retweets by checking for the "reposted" indicator.
    private static let extractionScript = """
    (function() {
        var tweets = [];
        var articles = document.querySelectorAll('article[data-testid="tweet"]');

        for (var i = 0; i < articles.length; i++) {
            var article = articles[i];

            // Skip retweets: look for "reposted" social context
            var socialContext = article.querySelector('[data-testid="socialContext"]');
            if (socialContext && socialContext.textContent.toLowerCase().includes('repost')) {
                continue;
            }

            // Get tweet text
            var tweetTextEl = article.querySelector('[data-testid="tweetText"]');
            var tweetText = tweetTextEl ? tweetTextEl.innerText : '';

            // Get author info
            var userNameEl = article.querySelector('[data-testid="User-Name"]');
            var displayName = '';
            var handle = '';
            if (userNameEl) {
                var spans = userNameEl.querySelectorAll('span');
                for (var j = 0; j < spans.length; j++) {
                    var text = spans[j].textContent.trim();
                    if (text.startsWith('@')) {
                        handle = text;
                        break;
                    }
                }
                // Display name is the first meaningful text
                var nameLinks = userNameEl.querySelectorAll('a');
                if (nameLinks.length > 0) {
                    var firstLink = nameLinks[0];
                    displayName = firstLink.textContent.trim();
                }
            }

            // Get tweet URL from the time element's parent link
            var timeEl = article.querySelector('time');
            var tweetURL = '';
            var dateStr = '';
            if (timeEl) {
                dateStr = timeEl.getAttribute('datetime') || '';
                var linkEl = timeEl.closest('a');
                if (linkEl) {
                    tweetURL = linkEl.href;
                }
            }

            // Get first image if present
            var imageURL = '';
            var imgEl = article.querySelector('[data-testid="tweetPhoto"] img');
            if (imgEl) {
                imageURL = imgEl.src;
            }

            if (tweetText || tweetURL) {
                tweets.push({
                    text: tweetText,
                    author: displayName,
                    handle: handle,
                    url: tweetURL,
                    imageURL: imageURL,
                    date: dateStr
                });
            }
        }

        return JSON.stringify(tweets);
    })()
    """

    private func extractTweets() {
        guard let webView, let continuation else {
            finishWithResult([])
            return
        }
        self.continuation = nil

        webView.evaluateJavaScript(Self.extractionScript) { [weak self] result, error in
            guard let self else { return }

            var tweets: [ParsedTweet] = []

            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let rawTweets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for raw in rawTweets {
                    let text = raw["text"] as? String ?? ""
                    let author = raw["author"] as? String ?? ""
                    let handle = raw["handle"] as? String ?? ""
                    let url = raw["url"] as? String ?? ""
                    let imageURL = raw["imageURL"] as? String
                    let dateStr = raw["date"] as? String ?? ""

                    guard !url.isEmpty else { continue }

                    // Parse ISO 8601 date
                    var publishedDate: Date?
                    if !dateStr.isEmpty {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        publishedDate = formatter.date(from: dateStr)
                        if publishedDate == nil {
                            formatter.formatOptions = [.withInternetDateTime]
                            publishedDate = formatter.date(from: dateStr)
                        }
                    }

                    let cleanHandle = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle

                    // Generate a tweet ID from the URL
                    let tweetID = url.split(separator: "/").last.map(String.init) ?? UUID().uuidString

                    tweets.append(ParsedTweet(
                        id: tweetID,
                        text: text,
                        author: author,
                        authorHandle: cleanHandle,
                        url: url,
                        imageURL: imageURL?.isEmpty == true ? nil : imageURL,
                        publishedDate: publishedDate
                    ))
                }
            }

            self.cleanup()
            continuation.resume(returning: tweets)
        }
    }

    private func finishWithTimeout() {
        // Try extraction even on timeout — some content may have loaded
        extractTweets()
    }

    private func finishWithResult(_ tweets: [ParsedTweet]) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cleanup()
        continuation.resume(returning: tweets)
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }
}
