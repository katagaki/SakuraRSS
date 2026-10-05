import Foundation
import WebKit

public extension RedditWebFeedScraper {
    func fetchPost(from url: URL) async throws -> RedditPostFetchResult {
        guard let postID = RedditProvider.postID(from: url) else {
            throw RedditPostFetchError.invalidURL
        }
        defer {
            webView.stopLoading()
            webView.navigationDelegate = nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.reddit.com"
        components.path = "/comments/\(postID)/"
        guard let pageURL = components.url else { throw RedditPostFetchError.invalidURL }
        try await load(pageURL)
        guard let encodedID = String(data: try JSONEncoder().encode(postID), encoding: .utf8) else {
            throw RedditPostFetchError.invalidURL
        }
        let script = "(\(Self.postSnapshotScript))(\(encodedID))"
        for _ in 0..<10 {
            let snapshot: RedditWebContentSnapshot = try await evaluateSnapshot(script)
            if snapshot.found && !snapshot.challenge {
                return await snapshot.postResult(baseURL: pageURL)
            }
            try await Task.sleep(for: .seconds(1))
        }
        let snapshot: RedditWebContentSnapshot = try await evaluateSnapshot(script)
        throw snapshot.challenge ? RedditWebFeedError.challenge : RedditPostFetchError.parseFailed
    }
}

extension RedditWebFeedScraper {
    func evaluateSnapshot<Snapshot: Decodable>(_ script: String) async throws -> Snapshot {
        guard let payload = try await webView.evaluateJavaScript(script) as? String,
              let data = payload.data(using: .utf8) else {
            throw RedditWebFeedError.loadFailed
        }
        return try JSONDecoder().decode(Snapshot.self, from: data)
    }
}
