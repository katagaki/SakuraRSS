import Foundation
import WebKit

extension RedditWebFeedScraper {
    func scrapePage(
        into posts: inout [RedditWebPost],
        seenIDs: inout Set<String>,
        existingPostIDs: Set<String>,
        limit: Int
    ) async throws -> Bool {
        var stalledScrolls = 0
        for scrollIndex in 0..<15 {
            try Task.checkCancellation()
            let snapshot = try await scrapeSnapshot()
            if snapshot.challenge { throw RedditWebFeedError.challenge }
            let previousCount = posts.count
            for post in snapshot.posts where seenIDs.insert(post.id).inserted {
                if existingPostIDs.contains(post.id) { return true }
                posts.append(post)
                if posts.count >= limit { return true }
            }
            stalledScrolls = posts.count == previousCount ? stalledScrolls + 1 : 0
            if stalledScrolls >= 3 && !posts.isEmpty { break }
            if scrollIndex == 14 { break }
            _ = try await webView.evaluateJavaScript("window.scrollTo(0, document.body.scrollHeight)")
            try await Task.sleep(for: .milliseconds(750))
        }
        return false
    }

    func nextPageURL(from pageURL: URL, after postID: String) -> URL? {
        guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "after" }
        components.queryItems?.append(URLQueryItem(name: "after", value: "t3_\(postID)"))
        return components.url
    }
}
