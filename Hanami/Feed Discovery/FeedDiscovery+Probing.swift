import Foundation

public extension FeedDiscovery {

    // MARK: - RSS Suffix Probing

    /// Tries appending `.rss` to non-root URL paths.
    func probeRSSSuffix(for url: URL) async -> DiscoveredFeed? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        let path = components.percentEncodedPath
        guard !path.isEmpty,
              path != "/",
              !path.hasSuffix(".rss"),
              !path.hasSuffix(".xml"),
              !path.hasSuffix(".atom") else {
            return nil
        }

        let trimmedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let domain = components.percentEncodedHost else { return nil }

        return await Self.probeFeedAt(domain: domain, path: "\(trimmedPath).rss")
    }

    // MARK: - Common Path Probing

    func probeCommonPaths(domain: String) async -> [DiscoveredFeed] {
        var results: [DiscoveredFeed] = []

        await withTaskGroup(of: DiscoveredFeed?.self) { group in
            for path in commonPaths {
                group.addTask {
                    await Self.probeFeedAt(domain: domain, path: path)
                }
            }

            for await result in group {
                if let feed = result {
                    results.append(feed)
                }
            }
        }

        return results
    }

    nonisolated static func probeFeedAt(domain: String, path: String) async -> DiscoveredFeed? {
        guard let url = Self.probeURL(domain: domain, path: path) else { return nil }

        do {
            var request = URLRequest.sakura(url: url, timeoutInterval: 10)
            request.httpMethod = "GET"

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            let isXML = contentType.contains("xml") || contentType.contains("rss") || contentType.contains("atom")

            let looksLikeFeed: Bool = {
                guard !isXML else { return false }
                let head = String(bytes: data.prefix(4096), encoding: .isoLatin1) ?? ""
                return head.contains("<rss") || head.contains("<feed") || head.contains("<rdf:RDF")
            }()

            if isXML || looksLikeFeed {
                let parser = RSSParser()
                if let parsed = parser.parse(data: data) {
                    return DiscoveredFeed(
                        title: parsed.title.isEmpty ? domain : parsed.title,
                        url: url.absoluteString,
                        siteURL: parsed.siteURL.isEmpty ? "https://\(domain)" : parsed.siteURL
                    )
                }
            }
        } catch {
        }

        return nil
    }

    nonisolated static func probeURL(domain: String, path: String) -> URL? {
        if let url = URL(string: "https://\(domain)\(path)") {
            return url
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = path
        return components.url
    }
}
