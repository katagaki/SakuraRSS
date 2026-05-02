import Foundation

enum HackerNewsPostFetchError: Error {
    case invalidURL
    case badResponse
    case parseFailed
}

/// Fetches a Hacker News self-post (Ask HN, Show HN with body, etc.) via the
/// Firebase API and returns the raw HTML body. Posts whose RSS link is an
/// external URL (regular link posts) are not handled here: the standard
/// extractor handles those.
nonisolated enum HackerNewsPostFetcher {

    /// `true` when `articleURL` is a Hacker News thread URL, which on HN
    /// means the post has no external link and the body lives on HN itself.
    static func isSelfPostURL(_ articleURL: URL) -> Bool {
        guard let host = articleURL.host?.lowercased(),
              host == HackerNewsProvider.host || host.hasSuffix(".\(HackerNewsProvider.host)") else {
            return false
        }
        return HackerNewsProvider.threadID(from: articleURL) != nil
    }

    /// Fetches the HN item and returns its `text` HTML. Returns `nil` when the
    /// item is deleted/dead or has no body.
    static func fetchPostText(for articleURL: URL) async throws -> String? {
        guard let threadID = HackerNewsProvider.threadID(from: articleURL),
              let itemURL = URL(
                string: "https://hacker-news.firebaseio.com/v0/item/\(threadID).json"
              ) else {
            throw HackerNewsPostFetchError.invalidURL
        }
        log("Extract", "HN post fetch begin id=\(threadID)")
        let request = URLRequest.sakura(url: itemURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        log("Extract", "HN GET \(itemURL.absoluteString) status=\(status) bytes=\(data.count)")
        guard (200..<300).contains(status) else {
            throw HackerNewsPostFetchError.badResponse
        }
        let item: HackerNewsFirebaseItem
        do {
            item = try JSONDecoder().decode(HackerNewsFirebaseItem.self, from: data)
        } catch {
            throw HackerNewsPostFetchError.parseFailed
        }
        if item.deleted == true || item.dead == true {
            log("Extract", "HN post skipped (deleted/dead) id=\(threadID)")
            return nil
        }
        guard let text = item.text, !text.isEmpty else {
            log("Extract", "HN post has no body text id=\(threadID)")
            return nil
        }
        log("Extract", "HN post ok id=\(threadID) chars=\(text.count)")
        return text
    }
}
