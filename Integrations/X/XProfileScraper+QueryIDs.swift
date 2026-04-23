import Foundation
import WebKit

// MARK: - Dynamic Query ID Fetching

extension XProfileScraper {

    /// Fetches x.com HTML, finds the main JS bundle, and extracts GraphQL query IDs.
    @MainActor
    static func fetchQueryIDsIfNeeded() async {
        guard !queryIDsFetched else { return }
        queryIDsFetched = true

        print("[XProfileScraper:QueryIDs] Starting query ID fetch…")

        await warmCookieStore()

        let cookies = await getHTTPCookies()
        print("[XProfileScraper:QueryIDs] Got \(cookies.count) cookies for x.com")

        await fetchQueryIDsFromBundle(cookies: cookies)

        if userByScreenNameQueryID == nil || userTweetsQueryID == nil
            || tweetDetailQueryID == nil {
            print("[XProfileScraper:QueryIDs] WARNING: Not all query IDs extracted. "
                  + "UserByScreenName=\(userByScreenNameQueryID ?? "nil"), "
                  + "UserTweets=\(userTweetsQueryID ?? "nil"), "
                  + "TweetDetail=\(tweetDetailQueryID ?? "nil")")
        } else {
            print("[XProfileScraper:QueryIDs] All query IDs extracted successfully")
        }
    }

    // MARK: - Cookie Warming

    @MainActor
    static var cookieStoreWarmed = false

    @MainActor
    static func warmCookieStore() async {
        guard !cookieStoreWarmed else { return }
        cookieStoreWarmed = true

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = sakuraUserAgent

        guard let url = URL(string: "https://x.com/settings") else { return }
        webView.load(URLRequest(url: url, timeoutInterval: 10))
        try? await Task.sleep(for: .seconds(2))
    }

    @MainActor
    private static func getHTTPCookies() async -> [HTTPCookie] {
        let store = WKWebsiteDataStore.default()
        let allCookies = await store.httpCookieStore.allCookies()
        return allCookies.filter {
            let domain = $0.domain.lowercased()
            return domain.contains("x.com") || domain.contains("twitter.com")
        }
    }

    // MARK: - Bundle Parsing

    private static func fetchQueryIDsFromBundle(cookies: [HTTPCookie]) async {
        guard let pageURL = URL(string: "https://x.com") else { return }

        var request = URLRequest(url: pageURL)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        for (key, value) in cookieHeader {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let pageHTML: String
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                print("[XProfileScraper:QueryIDs] ERROR: Could not decode page HTML")
                return
            }
            pageHTML = html
            print("[XProfileScraper:QueryIDs] Fetched x.com HTML (\(html.count) chars)")
        } catch {
            print("[XProfileScraper:QueryIDs] ERROR fetching x.com: \(error)")
            return
        }

        guard let bundleURL = extractMainBundleURL(from: pageHTML) else {
            print("[XProfileScraper:QueryIDs] ERROR: Could not find main bundle URL in HTML")
            print("[XProfileScraper:QueryIDs] HTML preview: \(pageHTML.prefix(2000))")
            return
        }

        print("[XProfileScraper:QueryIDs] Found main bundle: \(bundleURL)")

        let bundleText: String
        do {
            let (data, _) = try await URLSession.shared.data(for: .sakura(url: bundleURL))
            guard let text = String(data: data, encoding: .utf8) else {
                print("[XProfileScraper:QueryIDs] ERROR: Could not decode bundle JS")
                return
            }
            bundleText = text
            print("[XProfileScraper:QueryIDs] Fetched bundle (\(text.count) chars)")
        } catch {
            print("[XProfileScraper:QueryIDs] ERROR fetching bundle: \(error)")
            return
        }

        extractQueryIDs(from: bundleText)
    }

    private static func extractMainBundleURL(from html: String) -> URL? {
        let pattern = #"(https://abs\.twimg\.com/responsive-web/client-web/main\.[a-zA-Z0-9]+\.js)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: html, range: NSRange(html.startIndex..., in: html)
              ),
              let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return URL(string: String(html[range]))
    }

    private static func extractQueryIDs(from bundleText: String) {
        let pattern = #"queryId:"([^"]+)",operationName:"(UserByScreenName|UserTweets|TweetDetail)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(
            in: bundleText, range: NSRange(bundleText.startIndex..., in: bundleText)
        )

        for match in matches {
            guard let idRange = Range(match.range(at: 1), in: bundleText),
                  let nameRange = Range(match.range(at: 2), in: bundleText)
            else { continue }

            let queryID = String(bundleText[idRange])
            let name = String(bundleText[nameRange])

            switch name {
            case "UserByScreenName" where userByScreenNameQueryID == nil:
                userByScreenNameQueryID = queryID
                print("[XProfileScraper:QueryIDs] ✓ UserByScreenName: \(queryID)")
            case "UserTweets" where userTweetsQueryID == nil:
                userTweetsQueryID = queryID
                print("[XProfileScraper:QueryIDs] ✓ UserTweets: \(queryID)")
            case "TweetDetail" where tweetDetailQueryID == nil:
                tweetDetailQueryID = queryID
                print("[XProfileScraper:QueryIDs] ✓ TweetDetail: \(queryID)")
            default:
                break
            }
        }
    }
}
