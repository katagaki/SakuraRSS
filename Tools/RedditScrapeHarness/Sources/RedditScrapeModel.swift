import Foundation
import Observation
import WebKit

struct RedditScrapedPost: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let author: String
    let created: String
}

@MainActor
@Observable
final class RedditScrapeModel: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    var subreddit = "iOSBeta"
    var sort = "new"
    var status = "Loading r/iOSBeta/new"
    var posts: [RedditScrapedPost] = []
    var afterID: String?

    private var scrapeTask: Task<Void, Never>?

    private var pageURL: URL {
        var components = URLComponents(string: "https://www.reddit.com/r/\(subreddit)/\(sort)/")!
        if let afterID {
            components.queryItems = [URLQueryItem(name: "after", value: "t3_\(afterID)")]
        }
        return components.url!
    }

    override init() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.customUserAgent = sakuraUserAgent
        webView.navigationDelegate = self
        reload()
    }

    func reload() {
        scrapeTask?.cancel()
        status = "Loading r/\(subreddit)/\(sort)"
        posts = []
        webView.load(.sakura(url: pageURL))
    }

    func load(subreddit: String) {
        self.subreddit = subreddit
        afterID = nil
        reload()
    }

    func load(sort: String) {
        self.sort = sort
        afterID = nil
        reload()
    }

    func loadNextPage() {
        afterID = posts.last?.id ?? afterID
        reload()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        status = "Page loaded; waiting for posts"
        scrapeTask = Task {
            for attempt in 1...10 {
                if Task.isCancelled { return }
                await scrapePage()
                if !posts.isEmpty { return }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                status = "r/\(subreddit): no posts after \(attempt) s"
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        status = "Navigation failed: \(error.localizedDescription)"
    }

    func scrape() {
        Task { await scrapePage() }
    }

    func loadMore() {
        Task {
            for _ in 0..<5 {
                _ = try? await webView.evaluateJavaScript(
                    "window.scrollTo(0, document.body.scrollHeight)"
                )
                try? await Task.sleep(for: .seconds(1))
                await scrapePage()
            }
        }
    }

    func runHeadless() {
        Task {
            do {
                let requestedURL = pageURL
                let scraper = RedditWebFeedScraper()
                let fetchedPosts = try await scraper.fetch(
                    from: requestedURL,
                    existingPostIDs: []
                )
                afterID = fetchedPosts.last?.id
                let identifiers = "first=\(fetchedPosts.first?.id ?? ""), last=\(afterID ?? "")"
                let stopCount: Int
                if fetchedPosts.count > 10 {
                    let stoppedPosts = try await RedditWebFeedScraper().fetch(
                        from: requestedURL,
                        existingPostIDs: [fetchedPosts[10].id]
                    )
                    stopCount = stoppedPosts.count
                } else {
                    stopCount = -1
                }
                status = "r/\(subreddit)/\(sort): headless \(fetchedPosts.count), stop=\(stopCount), \(identifiers)"
                print("REDDIT_HEADLESS \(status)")
            } catch {
                status = "r/\(subreddit): headless failed: \(error)"
                print("REDDIT_HEADLESS r/\(subreddit) error=\(error)")
            }
        }
    }

    private func scrapePage() async {
        let script = #"""
        (() => {
          const elements = Array.from(document.querySelectorAll('shreddit-post'));
          const posts = elements.map(element => {
            const link = element.querySelector('a[href*="/comments/"]');
            const path = element.getAttribute('permalink') || link?.getAttribute('href') || '';
            const match = path.match(/\/comments\/([a-z0-9]+)/i);
            return {
              id: element.getAttribute('post-id') || match?.[1] || '',
              title: element.getAttribute('post-title') || link?.textContent?.trim() || '',
              url: path ? new URL(path, location.origin).href : '',
              author: element.getAttribute('author') || '',
              created: element.getAttribute('created-timestamp') || ''
            };
          }).filter(post => post.id && post.title && post.url);
          return JSON.stringify({ posts, count: elements.length, title: document.title,
            userAgent: navigator.userAgent,
            cursor: elements.at(-1)?.getAttribute('more-posts-cursor') || '',
            nextLink: document.querySelector('a[href*="after="]')?.getAttribute('href') || '',
            challenge: !!document.querySelector('form[action*="challenge"]') ||
              document.body.innerText.includes('prove you are human') });
        })()
        """#
        do {
            guard let payload = try await webView.evaluateJavaScript(script) as? String,
                  let data = payload.data(using: .utf8) else {
                status = "No JavaScript result"
                return
            }
            let result = try JSONDecoder().decode(RedditScrapeResult.self, from: data)
            posts = result.posts
            let countSummary = "\(result.posts.count) posts, \(result.count) elements"
            let userAgentMatches = result.userAgent == sakuraUserAgent
            let firstPostID = result.posts.first?.id ?? "none"
            status = "r/\(subreddit): \(countSummary), first=\(firstPostID)"
                + ", cursor=\(result.cursor.prefix(24)), next=\(result.nextLink.prefix(24))"
                + ", challenge=\(result.challenge), UA=\(userAgentMatches)"
            print("REDDIT_HARNESS \(status)")
            print("REDDIT_HARNESS_CURSOR cursor=\(result.cursor), next=\(result.nextLink)")
            for post in result.posts.prefix(3) {
                print("REDDIT_HARNESS_POST \(post.id) \(post.title) \(post.url)")
            }
        } catch {
            status = "Extraction failed: \(error.localizedDescription)"
            print("REDDIT_HARNESS \(status)")
        }
    }
}

private struct RedditScrapeResult: Decodable {
    let posts: [RedditScrapedPost]
    let count: Int
    let title: String
    let userAgent: String
    let cursor: String
    let nextLink: String
    let challenge: Bool
}
