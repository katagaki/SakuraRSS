import Foundation

/// Single entry point for Reddit-backed feeds: subreddit metadata
/// (`/r/<sub>/about.json`), recent-post image listings (`/r/<sub>/new.json`),
/// and per-post content (`/comments/<id>.json`). The post-content fetch keeps
/// an LRU cache so reopening the same article is free.
final class RedditProvider: @unchecked Sendable {

    static let shared = RedditProvider()

    private let postCacheCapacity = 16
    private var postCache: [String: RedditPostFetchResult] = [:]
    private var postCacheOrder: [String] = []
    private let postCacheQueue = DispatchQueue(label: "RedditProvider.postCache")

    private init() {}

    // MARK: - Subreddit URL Helpers

    nonisolated static func isRedditSubredditURL(_ url: URL) -> Bool {
        guard matchesHost(url.host) else { return false }
        return extractSubredditName(from: url) != nil
    }

    nonisolated static func extractSubredditName(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let rIndex = components.firstIndex(where: { $0.lowercased() == "r" }),
              rIndex + 1 < components.count else { return nil }
        let name = components[rIndex + 1]
        let cleaned = name.hasSuffix(".rss") ? String(name.dropLast(4)) : name
        return cleaned.isEmpty ? nil : cleaned
    }

    nonisolated static func aboutURL(for subreddit: String) -> URL? {
        URL(string: "https://www.reddit.com/r/\(subreddit)/about.json")
    }

    nonisolated static func listingURL(for subreddit: String, limit: Int = 50) -> URL? {
        URL(string: "https://www.reddit.com/r/\(subreddit)/new.json?raw_json=1&limit=\(limit)")
    }

    /// Reddit's image URLs are HTML-encoded inside JSON; only `&amp;` matters
    /// in practice.
    nonisolated static func unescapeAmpersand(_ input: String) -> String {
        input.replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Reddit's `community_icon` signed query params aren't needed; stripping
    /// keeps cache keys stable.
    nonisolated static func stripQuery(from urlString: String) -> String {
        let decoded = urlString.replacingOccurrences(of: "&amp;", with: "&")
        guard var components = URLComponents(string: decoded) else { return decoded }
        components.query = nil
        return components.string ?? decoded
    }

    // MARK: - Post URL Helpers

    nonisolated static func postID(from articleURL: URL) -> String? {
        let components = articleURL.pathComponents.filter { $0 != "/" }
        guard let commentsIndex = components.firstIndex(where: { $0.lowercased() == "comments" }),
              commentsIndex + 1 < components.count else { return nil }
        let candidate = components[commentsIndex + 1]
        return candidate.isEmpty ? nil : candidate
    }

    nonisolated static func postJSONURL(for postID: String) -> URL? {
        URL(string: "https://www.reddit.com/comments/\(postID).json?raw_json=1")
    }

    // MARK: - Public Fetch Methods

    func fetchCommunity(subreddit: String) async -> RedditCommunityFetchResult {
        guard let url = Self.aboutURL(for: subreddit) else {
            return RedditCommunityFetchResult(communityIconURL: nil)
        }
        return await performCommunityFetch(url: url)
    }

    func fetchListing(subreddit: String) async -> RedditListingFetchResult {
        guard let url = Self.listingURL(for: subreddit) else {
            return RedditListingFetchResult(imagesByPostID: [:])
        }
        return await performListingFetch(url: url)
    }

    func fetchContent(for article: Article) async throws -> RedditPostFetchResult {
        guard let url = URL(string: article.url),
              let postID = Self.postID(from: url) else {
            throw RedditPostFetchError.invalidURL
        }

        if let cached = cachedPostResult(for: postID) {
            return cached
        }

        let result = try await performPostFetch(postID: postID)
        storePostResult(result, for: postID)
        return result
    }

    // MARK: - Post Cache

    func cachedPostResult(for postID: String) -> RedditPostFetchResult? {
        postCacheQueue.sync {
            guard let value = postCache[postID] else { return nil }
            if let index = postCacheOrder.firstIndex(of: postID) {
                postCacheOrder.remove(at: index)
                postCacheOrder.append(postID)
            }
            return value
        }
    }

    func storePostResult(_ result: RedditPostFetchResult, for postID: String) {
        postCacheQueue.sync {
            if postCache[postID] != nil,
               let index = postCacheOrder.firstIndex(of: postID) {
                postCacheOrder.remove(at: index)
            }
            postCache[postID] = result
            postCacheOrder.append(postID)
            while postCacheOrder.count > postCacheCapacity {
                let evicted = postCacheOrder.removeFirst()
                postCache.removeValue(forKey: evicted)
            }
        }
    }

    func clearPostCache() {
        postCacheQueue.sync {
            postCache.removeAll()
            postCacheOrder.removeAll()
        }
    }
}
