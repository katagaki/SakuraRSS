import Foundation

enum RedditPostFetchResult: Sendable {
    case markerString(String)
    case linkedArticle(URL)
}

/// Fetches Reddit posts and translates them into `ContentBlock` marker strings.
final class RedditPostFetcher: @unchecked Sendable {

    static let shared = RedditPostFetcher()

    private let cacheCapacity = 16
    private var cache: [String: RedditPostFetchResult] = [:]
    private var cacheOrder: [String] = []
    private let cacheQueue = DispatchQueue(label: "RedditPostFetcher.cache")

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

    nonisolated static func postID(from articleURL: URL) -> String? {
        let components = articleURL.pathComponents.filter { $0 != "/" }
        guard let commentsIndex = components.firstIndex(where: { $0.lowercased() == "comments" }),
              commentsIndex + 1 < components.count else { return nil }
        let candidate = components[commentsIndex + 1]
        return candidate.isEmpty ? nil : candidate
    }

    nonisolated static func jsonURL(for postID: String) -> URL? {
        URL(string: "https://www.reddit.com/comments/\(postID).json?raw_json=1")
    }

    func fetchContent(for article: Article) async throws -> RedditPostFetchResult {
        guard let url = URL(string: article.url),
              let postID = Self.postID(from: url) else {
            throw RedditPostFetcherError.invalidURL
        }

        if let cached = cachedResult(for: postID) {
            return cached
        }

        let result = try await performFetch(postID: postID)
        storeResult(result, for: postID)
        return result
    }
}

enum RedditPostFetcherError: Error {
    case invalidURL
    case badResponse
    case rateLimited
    case parseFailed
}
