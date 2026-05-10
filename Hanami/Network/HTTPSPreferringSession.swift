import Foundation

/// Shared `URLSession` that intercepts HTTP redirects and rewrites
/// `http://` redirect targets to `https://` so unexpected scheme
/// downgrades don't trip App Transport Security and abort the fetch.
///
/// Servers occasionally 30x from `https://` to `http://` (canonical-host
/// quirks, misconfigured load balancers, etc.). Without this rewrite, the
/// follow-up request is blocked by ATS and the fetch fails outright; the
/// HTTPS variant almost always works in practice.
public final class HTTPSPreferringSession: @unchecked Sendable {

    public static let shared = HTTPSPreferringSession()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        self.session = URLSession(
            configuration: configuration,
            delegate: HTTPSRedirectDelegate(),
            delegateQueue: queue
        )
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: HTTPSRedirectDelegate.upgradeIfNeeded(request))
    }
}

private final class HTTPSRedirectDelegate: NSObject, URLSessionTaskDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(Self.upgradeIfNeeded(request))
    }

    nonisolated static func upgradeIfNeeded(_ request: URLRequest) -> URLRequest {
        guard let url = request.url, url.scheme?.lowercased() == "http",
              let upgraded = httpsURL(from: url) else { return request }
        var modified = request
        modified.url = upgraded
        if let host = upgraded.host,
           let referer = URL(string: "https://\(host)/") {
            modified.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        return modified
    }

    private nonisolated static func httpsURL(from url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }
}
