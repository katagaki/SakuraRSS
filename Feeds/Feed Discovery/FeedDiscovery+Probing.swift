import Foundation

extension FeedDiscovery {

    // MARK: - RSS Suffix Probing

    /// Tries appending `.rss` to non-root URL paths.
    func probeRSSSuffix(for url: URL) async -> DiscoveredFeed? {
        let path = url.path
        guard !path.isEmpty,
              path != "/",
              !path.hasSuffix(".rss"),
              !path.hasSuffix(".xml"),
              !path.hasSuffix(".atom") else {
            return nil
        }

        let trimmedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let domain = url.host else { return nil }

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
        guard let url = URL(string: "https://\(domain)\(path)") else { return nil }

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
                guard let prefix = String(data: data.prefix(500), encoding: .utf8) else { return false }
                return prefix.contains("<rss") || prefix.contains("<feed")
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
}
