import Foundation

extension NoteProvider: ProfileFeedProvider {

    nonisolated static var providerID: String { "note" }

    nonisolated static var domains: Set<String> { [host] }

    /// `nil` because note feeds use a real `https://note.com/<handle>/rss` URL,
    /// not a pseudo-scheme. `isFeedURL`/`identifierFromFeedURL` are overridden below.
    nonisolated static var feedURLScheme: String? { nil }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isNoteHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1 else { return false }
        return isValidHandle(components[0])
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard isNoteHost(url.host) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first else { return nil }
        return isValidHandle(first) ? first : nil
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "https://note.com/\(identifier)/rss"
    }

    nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let parsed = URL(string: url), isNoteHost(parsed.host) else { return false }
        let components = parsed.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              components.last?.lowercased() == "rss" else { return false }
        return isValidHandle(components[0])
    }

    nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard isFeedURL(url),
              let parsed = URL(string: url) else { return nil }
        return parsed.pathComponents.filter { $0 != "/" }.first
    }

    /// Probes the constructed RSS URL to verify the creator publishes a feed
    /// before suggesting it.
    nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let handle = extractIdentifier(from: url) else { return nil }
        return await FeedDiscovery.probeFeedAt(domain: host, path: "/\(handle)/rss")
    }
}
