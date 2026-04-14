import Foundation

/// Result of resolving a Reddit post into renderable content.
///
/// - `markerString`: A fully-formed `ContentBlock` marker string (mix of
///   plain text, `{{IMG}}…{{/IMG}}`, and `{{VIDEO}}…{{/VIDEO}}`) ready to be
///   cached and parsed by `ContentBlock.parse(_:)`.
/// - `linkedArticle`: The post is a link post that points off-reddit. Callers
///   should fall through to the generic article extractor against this URL
///   instead of the Reddit permalink.
enum RedditPostFetchResult: Sendable {
    case markerString(String)
    case linkedArticle(URL)
}

/// Scrapes Reddit's public `/comments/{id}.json` endpoint (no auth required)
/// and translates posts into the same `ContentBlock` marker-string format
/// that generic articles use. Reddit feeds continue to be refreshed through
/// the regular RSS pipeline; this scraper is only consulted from
/// `ArticleDetailView`'s extraction step to fetch the full post content.
final class RedditPostScraper: @unchecked Sendable {

    static let shared = RedditPostScraper()

    // MARK: - LRU cache

    /// Small in-memory LRU so backing out and reopening the same post in one
    /// session doesn't refetch the JSON.
    private let cacheCapacity = 16
    private var cache: [String: RedditPostFetchResult] = [:]
    private var cacheOrder: [String] = []
    private let cacheQueue = DispatchQueue(label: "RedditPostScraper.cache")

    private init() {}

    func cachedResult(for postID: String) -> RedditPostFetchResult? {
        cacheQueue.sync {
            guard let value = cache[postID] else { return nil }
            if let index = cacheOrder.firstIndex(of: postID) {
                cacheOrder.remove(at: index)
                cacheOrder.append(postID)
            }
            return value
        }
    }

    func storeResult(_ result: RedditPostFetchResult, for postID: String) {
        cacheQueue.sync {
            if cache[postID] != nil {
                if let index = cacheOrder.firstIndex(of: postID) {
                    cacheOrder.remove(at: index)
                }
            }
            cache[postID] = result
            cacheOrder.append(postID)
            while cacheOrder.count > cacheCapacity {
                let evicted = cacheOrder.removeFirst()
                cache.removeValue(forKey: evicted)
            }
        }
    }

    func clearCache() {
        cacheQueue.sync {
            cache.removeAll()
            cacheOrder.removeAll()
        }
    }

    // MARK: - Post ID extraction

    /// Extracts the base-36 post ID from a Reddit permalink such as
    /// `https://www.reddit.com/r/swift/comments/abc123/some_title/`.
    nonisolated static func postID(from articleURL: URL) -> String? {
        let components = articleURL.pathComponents.filter { $0 != "/" }
        guard let commentsIndex = components.firstIndex(where: { $0.lowercased() == "comments" }),
              commentsIndex + 1 < components.count else { return nil }
        let candidate = components[commentsIndex + 1]
        return candidate.isEmpty ? nil : candidate
    }

    /// Constructs the public JSON endpoint for a post.
    nonisolated static func jsonURL(for postID: String) -> URL? {
        URL(string: "https://www.reddit.com/comments/\(postID).json?raw_json=1")
    }

    // MARK: - Public entry point

    /// Fetches a Reddit post's content and returns it as either a renderable
    /// marker string or a URL that should be extracted via the generic
    /// `ArticleExtractor` flow.
    func fetchContent(for article: Article) async throws -> RedditPostFetchResult {
        guard let url = URL(string: article.url),
              let postID = Self.postID(from: url) else {
            throw RedditPostScraperError.invalidURL
        }

        if let cached = cachedResult(for: postID) {
            return cached
        }

        let result = try await performFetch(postID: postID)
        storeResult(result, for: postID)
        return result
    }
}

enum RedditPostScraperError: Error {
    case invalidURL
    case badResponse
    case rateLimited
    case parseFailed
}
