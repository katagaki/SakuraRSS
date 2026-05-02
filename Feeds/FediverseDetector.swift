import Foundation

/// Probes a host for Fediverse signals by issuing HEAD requests against the
/// canonical `.well-known` paths. The probe stops at the first success, so we
/// only pay for additional round-trips when the cheaper checks fail.
nonisolated enum FediverseDetector {

    /// `.well-known` paths probed in order. Webfinger comes first because
    /// every well-formed Fediverse instance must serve it.
    private static let wellKnownPaths: [String] = [
        "/.well-known/webfinger",
        "/.well-known/host-meta",
        "/.well-known/nodeinfo"
    ]

    /// In-process cache so repeated probes for the same host (multiple feeds
    /// on one instance) don't re-issue the same HEAD requests.
    private static let cache = HostCache()

    private static let probeTimeout: TimeInterval = 4

    /// Returns `true` if any of the probe paths responds with HTTP 200.
    /// `nil` means the host could not be derived from `feed.siteURL` /
    /// `feed.fetchURL`; the caller should leave the cached flag untouched.
    static func detect(for feed: Feed) async -> Bool? {
        guard let host = probeHost(for: feed) else {
            log("FediverseDetector", "skip id=\(feed.id) reason=no-host siteURL=\(feed.siteURL) fetchURL=\(feed.fetchURL)")
            return nil
        }
        if let cached = await cache.value(for: host) {
            log("FediverseDetector", "cache hit id=\(feed.id) host=\(host) result=\(cached)")
            return cached
        }
        log("FediverseDetector", "probe begin id=\(feed.id) host=\(host)")
        let result = await probe(host: host, feedID: feed.id)
        await cache.set(result, for: host)
        log("FediverseDetector", "probe end id=\(feed.id) host=\(host) result=\(result)")
        return result
    }

    private static func probeHost(for feed: Feed) -> String? {
        let candidate = URL(string: feed.siteURL)?.host
            ?? URL(string: feed.fetchURL)?.host
        guard let host = candidate?.lowercased(), !host.isEmpty else { return nil }
        return host
    }

    private static func probe(host: String, feedID: Int64) async -> Bool {
        for path in wellKnownPaths {
            guard let url = URL(string: "https://\(host)\(path)") else {
                log("FediverseDetector", "probe path bad-url id=\(feedID) host=\(host) path=\(path)")
                continue
            }
            let started = Date()
            let (status, hit) = await statusCode(for: url)
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            // swiftlint:disable:next line_length
            log("FediverseDetector", "probe path id=\(feedID) host=\(host) path=\(path) status=\(status) elapsedMs=\(elapsedMs) hit=\(hit)")
            if hit { return true }
        }
        return false
    }

    private static func statusCode(for url: URL) async -> (status: Int, isHit: Bool) {
        var request = URLRequest.sakura(url: url, timeoutInterval: probeTimeout)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            return (code, code == 200)
        } catch {
            log("FediverseDetector", "probe error url=\(url.absoluteString) error=\(error.localizedDescription)")
            return (-1, false)
        }
    }

    private actor HostCache {
        private var storage: [String: Bool] = [:]

        func value(for host: String) -> Bool? { storage[host] }

        func set(_ value: Bool, for host: String) { storage[host] = value }
    }
}
