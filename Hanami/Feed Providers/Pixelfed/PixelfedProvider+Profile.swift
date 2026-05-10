import Foundation

extension PixelfedProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "pixelfed" }

    public nonisolated static var domains: Set<String> { knownHosts }

    /// `nil` because Pixelfed feeds use a real `https://<host>/@<user>.rss`
    /// URL, not a pseudo-scheme. `isFeedURL`/`identifierFromFeedURL` are
    /// overridden below.
    public nonisolated static var feedURLScheme: String? { nil }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isPixelfedHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first, !first.isEmpty,
              !first.hasPrefix("@") else { return false }
        return true
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard isProfileURL(url) else { return nil }
        return url.pathComponents.filter { $0 != "/" }.first
    }

    public nonisolated static func feedURL(for identifier: String) -> String {
        "https://pixelfed.social/@\(identifier).rss"
    }

    public nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let parsed = URL(string: url),
              isPixelfedHost(parsed.host) else { return false }
        let path = parsed.path
        return path.hasPrefix("/@") && path.hasSuffix(".rss")
    }

    public nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard isFeedURL(url),
              let parsed = URL(string: url) else { return nil }
        let trimmed = parsed.path.dropFirst(2).dropLast(4)
        let username = trimmed.split(separator: "/").first.map(String.init) ?? ""
        return username.isEmpty ? nil : username
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let host = url.host?.lowercased(),
              let username = extractIdentifier(from: url) else { return nil }
        return DiscoveredFeed(
            title: "@\(username)",
            url: "https://\(host)/@\(username).rss",
            siteURL: url.absoluteString
        )
    }
}
