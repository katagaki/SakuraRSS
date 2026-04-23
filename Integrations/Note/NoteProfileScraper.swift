import Foundation

struct NoteProfileScrapeResult: Sendable {
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches note.com creator metadata via the public v2 creators API.
final class NoteProfileScraper {

    nonisolated static let reservedHandles: Set<String> = [
        "api", "search", "magazine", "magazines", "circle", "login", "signup",
        "hashtag", "topic", "topics", "notifications", "settings", "m", "info",
        "help", "contest", "timeline", "notes", "n"
    ]

    // MARK: - Static Helpers

    nonisolated static func isNoteProfileURL(_ url: URL) -> Bool {
        guard isNoteHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1 else { return false }
        return isValidHandle(components[0])
    }

    nonisolated static func isNoteFeedURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        guard isNoteHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              components.last?.lowercased() == "rss" else { return false }
        return isValidHandle(components[0])
    }

    nonisolated static func extractHandle(from url: URL) -> String? {
        guard isNoteHost(url.host) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first else { return nil }
        return isValidHandle(first) ? first : nil
    }

    nonisolated static func feedURL(for handle: String) -> String {
        "https://note.com/\(handle)/rss"
    }

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://note.com/\(handle)")
    }

    nonisolated static func creatorAPIURL(for handle: String) -> URL? {
        URL(string: "https://note.com/api/v2/creators/\(handle)")
    }

    private nonisolated static func isNoteHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "note.com" || host == "www.note.com"
    }

    private nonisolated static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return false }
        return !reservedHandles.contains(handle.lowercased())
    }

    // MARK: - Public

    func scrapeProfile(handle: String) async -> NoteProfileScrapeResult {
        guard let url = Self.creatorAPIURL(for: handle) else {
            return NoteProfileScrapeResult(profileImageURL: nil, displayName: nil)
        }
        return await performFetch(url: url)
    }
}
