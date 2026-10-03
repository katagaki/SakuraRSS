import Foundation
import WebKit

struct RedditWebSnapshot: Decodable {
    let posts: [RedditWebPost]
    let challenge: Bool
}

extension RedditWebFeedScraper {
    func scrapeSnapshot() async throws -> RedditWebSnapshot {
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
          const bodyText = document.body.innerText.toLowerCase();
          return JSON.stringify({ posts,
            challenge: !!document.querySelector('form[action*="challenge"]') ||
              bodyText.includes('prove you are human') });
        })()
        """#
        guard let payload = try await webView.evaluateJavaScript(script) as? String,
              let data = payload.data(using: .utf8) else {
            throw RedditWebFeedError.loadFailed
        }
        return try JSONDecoder().decode(RedditWebSnapshot.self, from: data)
    }
}
