import Foundation

/// Result of scraping a note.com creator via the public `/api/v2/creators`
/// endpoint.
struct NoteProfileScrapeResult: Sendable {
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches note.com creator metadata (profile photo, display name) from the
/// public v2 creators API. No login required.
final class NoteProfileScraper {

    /// Path segments that live under `note.com` but are not creator handles.
    static let reservedHandles: Set<String> = [
        "api", "search", "magazine", "magazines", "circle", "login", "signup",
        "hashtag", "topic", "topics", "notifications", "settings", "m", "info",
        "help", "contest", "timeline", "notes", "n"
    ]

    // MARK: - Static Helpers

    /// Returns true if the URL points to a note.com creator profile page
    /// (e.g. `https://note.com/<urlname>`). Excludes RSS and article URLs.
    nonisolated static func isNoteProfileURL(_ url: URL) -> Bool {
        guard isNoteHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1 else { return false }
        return isValidHandle(components[0])
    }

    /// Returns true if the feed URL points at note.com's `/rss` endpoint.
    nonisolated static func isNoteFeedURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        guard isNoteHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              components.last?.lowercased() == "rss" else { return false }
        return isValidHandle(components[0])
    }

    /// Extracts the creator's urlname from any note.com URL (profile, RSS,
    /// article, etc.).
    nonisolated static func extractHandle(from url: URL) -> String? {
        guard isNoteHost(url.host) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first else { return nil }
        return isValidHandle(first) ? first : nil
    }

    /// Constructs the canonical RSS feed URL for a creator.
    nonisolated static func feedURL(for handle: String) -> String {
        "https://note.com/\(handle)/rss"
    }

    /// Constructs the public profile URL for a creator.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://note.com/\(handle)")
    }

    /// Constructs the v2 creators API URL used to fetch metadata.
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

    /// Fetches metadata for the given creator handle.
    func scrapeProfile(handle: String) async -> NoteProfileScrapeResult {
        guard let url = Self.creatorAPIURL(for: handle) else {
            return NoteProfileScrapeResult(profileImageURL: nil, displayName: nil)
        }
        return await performFetch(url: url)
    }
}
