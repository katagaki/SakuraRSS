import Foundation

struct SubstackPublicationScrapeResult: Sendable {
    let logoURL: String?
}

/// Fetches Substack publication metadata via the public `/api/v1/publication` endpoint.
final class SubstackPublicationScraper {

    // MARK: - Static Helpers

    nonisolated static func isSubstackHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "substack.com" || host.hasSuffix(".substack.com")
    }

    nonisolated static func isSubstackPublicationHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(),
              host.hasSuffix(".substack.com"),
              host != "www.substack.com",
              host != "on.substack.com",
              host != "open.substack.com" else { return false }
        return true
    }

    nonisolated static func isSubstackPublicationURL(_ url: URL) -> Bool {
        isSubstackPublicationHost(url.host)
    }

    nonisolated static func isSubstackFeedURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              isSubstackPublicationHost(url.host) else { return false }
        return url.path.hasSuffix("/feed")
    }

    nonisolated static func publicationAPIURL(for host: String) -> URL? {
        URL(string: "https://\(host)/api/v1/publication")
    }

    // MARK: - Public

    func scrapePublication(host: String) async -> SubstackPublicationScrapeResult {
        guard let url = Self.publicationAPIURL(for: host) else {
            return SubstackPublicationScrapeResult(logoURL: nil)
        }
        return await performFetch(url: url)
    }
}
