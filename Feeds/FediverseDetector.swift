import Foundation

/// Probes a host for Fediverse signals via NodeInfo discovery: GET
/// `/.well-known/nodeinfo`, follow the freshest schema link, and confirm
/// the document exposes a non-empty `software.name`. The two-step parse
/// rejects catch-all 200 responses that would fool a HEAD probe.
nonisolated enum FediverseDetector {

    private static let cache = HostCache()
    private static let probeTimeout: TimeInterval = 4

    /// NodeInfo schema rels in newest → oldest order, so the freshest link a
    /// host advertises wins.
    private static let nodeInfoRels: [String] = [
        "http://nodeinfo.diaspora.software/ns/schema/2.1",
        "http://nodeinfo.diaspora.software/ns/schema/2.0",
        "http://nodeinfo.diaspora.software/ns/schema/1.1",
        "http://nodeinfo.diaspora.software/ns/schema/1.0"
    ]

    /// Returns `true` if the host exposes a NodeInfo document with a non-empty
    /// `software.name`, `false` if the host responded cleanly without a
    /// Fediverse signal, or `nil` if the probe was inconclusive (host could
    /// not be derived, transport error, 5xx, rate-limit). The caller must
    /// leave the cached flag untouched on `nil` so the next refresh re-probes.
    static func detect(for feed: Feed) async -> Bool? {
        guard let host = probeHost(for: feed) else {
            // swiftlint:disable:next line_length
            log("FediverseDetector", "skip id=\(feed.id) reason=no-host siteURL=\(feed.siteURL) fetchURL=\(feed.fetchURL)")
            return nil
        }
        if let cached = await cache.value(for: host) {
            log("FediverseDetector", "cache hit id=\(feed.id) host=\(host) result=\(cached)")
            return cached
        }
        log("FediverseDetector", "probe begin id=\(feed.id) host=\(host)")
        let started = Date()
        let outcome = await nodeInfoOutcome(forHost: host, feedID: feed.id)
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        switch outcome {
        case .found(let software):
            // swiftlint:disable:next line_length
            log("FediverseDetector", "probe end id=\(feed.id) host=\(host) result=true software=\(software) elapsedMs=\(elapsedMs)")
            await cache.set(true, for: host)
            return true
        case .missing:
            log("FediverseDetector", "probe end id=\(feed.id) host=\(host) result=false elapsedMs=\(elapsedMs)")
            await cache.set(false, for: host)
            return false
        case .inconclusive:
            log("FediverseDetector", "probe end id=\(feed.id) host=\(host) result=inconclusive elapsedMs=\(elapsedMs)")
            return nil
        }
    }

    private static func probeHost(for feed: Feed) -> String? {
        let candidate = URL(string: feed.siteURL)?.host
            ?? URL(string: feed.fetchURL)?.host
        guard let host = candidate?.lowercased(), !host.isEmpty else { return nil }
        return host
    }

    /// Resolves the host's NodeInfo discovery + document into a tri-state
    /// outcome. Transport errors, 5xx, and rate-limit replies stay
    /// inconclusive so the caller can re-probe later instead of caching a
    /// sticky `false`.
    private static func nodeInfoOutcome(
        forHost host: String,
        feedID: Int64
    ) async -> NodeInfoOutcome {
        guard let discoveryURL = URL(string: "https://\(host)/.well-known/nodeinfo") else {
            log("FediverseDetector", "discovery bad-url id=\(feedID) host=\(host)")
            return .missing
        }
        switch await fetchJSON(NodeInfoDiscovery.self, from: discoveryURL) {
        case .inconclusive(let reason):
            log("FediverseDetector", "discovery inconclusive id=\(feedID) host=\(host) reason=\(reason)")
            return .inconclusive
        case .miss(let reason):
            log("FediverseDetector", "discovery miss id=\(feedID) host=\(host) reason=\(reason)")
            return .missing
        case .decoded(let discovery):
            guard let nodeInfoURL = pickNodeInfoURL(from: discovery.links, host: host) else {
                log("FediverseDetector", "discovery no-rel id=\(feedID) host=\(host) links=\(discovery.links.count)")
                return .missing
            }
            switch await fetchJSON(NodeInfoDocument.self, from: nodeInfoURL) {
            case .inconclusive(let reason):
                // swiftlint:disable:next line_length
                log("FediverseDetector", "document inconclusive id=\(feedID) host=\(host) url=\(nodeInfoURL.absoluteString) reason=\(reason)")
                return .inconclusive
            case .miss(let reason):
                // swiftlint:disable:next line_length
                log("FediverseDetector", "document miss id=\(feedID) host=\(host) url=\(nodeInfoURL.absoluteString) reason=\(reason)")
                return .missing
            case .decoded(let document):
                let name = document.software.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? .missing : .found(name.lowercased())
            }
        }
    }

    /// Picks the freshest supported NodeInfo URL whose `href` lives on the
    /// discovery host. The host check guards against malformed `.well-known`
    /// payloads pointing the probe at an unrelated origin.
    private static func pickNodeInfoURL(
        from links: [NodeInfoDiscovery.Link],
        host: String
    ) -> URL? {
        for rel in nodeInfoRels {
            guard let match = links.first(where: { $0.rel == rel }),
                  let url = URL(string: match.href),
                  url.host?.lowercased() == host else { continue }
            return url
        }
        return nil
    }

    /// Tri-state fetch so transport failures (`inconclusive`) don't get
    /// confused with clean HTTP responses that simply aren't NodeInfo
    /// (`miss`).
    private static func fetchJSON<T: Decodable>(
        _ type: T.Type,
        from url: URL
    ) async -> FetchResult<T> {
        var request = URLRequest.sakura(url: url, timeoutInterval: probeTimeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .inconclusive(reason: "no-http-response")
            }
            let status = http.statusCode
            if status == 429 || status >= 500 {
                return .inconclusive(reason: "status=\(status)")
            }
            if status != 200 {
                return .miss(reason: "status=\(status)")
            }
            do {
                return .decoded(try JSONDecoder().decode(T.self, from: data))
            } catch {
                return .miss(reason: "decode-error")
            }
        } catch let error as URLError where error.code == .cancelled {
            return .inconclusive(reason: "cancelled")
        } catch {
            return .inconclusive(reason: "transport-error")
        }
    }

    private enum NodeInfoOutcome {
        case found(String)
        case missing
        case inconclusive
    }

    private enum FetchResult<T> {
        case decoded(T)
        case miss(reason: String)
        case inconclusive(reason: String)
    }

    private struct NodeInfoDiscovery: Decodable {
        struct Link: Decodable {
            let rel: String
            let href: String
        }
        let links: [Link]
    }

    private struct NodeInfoDocument: Decodable {
        struct Software: Decodable {
            let name: String
        }
        let software: Software
    }

    private actor HostCache {
        private var storage: [String: Bool] = [:]

        func value(for host: String) -> Bool? { storage[host] }

        func set(_ value: Bool, for host: String) { storage[host] = value }
    }
}
