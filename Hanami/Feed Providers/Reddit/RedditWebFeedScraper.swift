import Foundation
import WebKit

public enum RedditWebFeedError: Error {
    case loadFailed
    case timedOut
    case challenge
    case noPosts
}

@MainActor
public final class RedditWebFeedScraper: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    public override init() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        super.init()
        webView.customUserAgent = sakuraUserAgent
        webView.navigationDelegate = self
    }

    public func fetch(
        from pageURL: URL,
        existingPostIDs: Set<String>,
        limit: Int = 50
    ) async throws -> [RedditWebPost] {
        guard limit > 0 else { return [] }
        defer {
            webView.stopLoading()
            webView.navigationDelegate = nil
        }
        var posts: [RedditWebPost] = []
        var seenIDs = Set<String>()
        var nextPageURL = pageURL
        for _ in 0..<10 {
            try await load(nextPageURL)
            let previousPageCount = posts.count
            if try await scrapePage(
                into: &posts,
                seenIDs: &seenIDs,
                existingPostIDs: existingPostIDs,
                limit: min(limit, 50)
            ) { return posts }
            guard posts.count > previousPageCount,
                  let lastPostID = posts.last?.id,
                  let pageURL = self.nextPageURL(from: pageURL, after: lastPostID) else { break }
            nextPageURL = pageURL
        }
        guard !posts.isEmpty else { throw RedditWebFeedError.noPosts }
        return posts
    }

    func load(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            webView.load(.sakura(url: url, timeoutInterval: 20))
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                self?.completeNavigation(.failure(RedditWebFeedError.timedOut))
            }
        }
        try await Task.sleep(for: .seconds(1))
    }

    public func webView(_: WKWebView, didFinish _: WKNavigation!) {
        completeNavigation(.success(()))
    }

    public func webView(
        _: WKWebView,
        didFail _: WKNavigation!,
        withError error: Error
    ) {
        completeNavigation(.failure(error))
    }

    public func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError error: Error
    ) {
        completeNavigation(.failure(error))
    }

    private func completeNavigation(_ result: Result<Void, Error>) {
        guard let navigationContinuation else { return }
        self.navigationContinuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        navigationContinuation.resume(with: result)
    }
}
