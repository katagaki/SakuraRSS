import Foundation

/// Fetches note.com creator metadata via the public v2 creators API.
final class NoteProvider {

    nonisolated static let host = "note.com"

    nonisolated static let reservedHandles: Set<String> = [
        "api", "search", "magazine", "magazines", "circle", "login", "signup",
        "hashtag", "topic", "topics", "notifications", "settings", "m", "info",
        "help", "contest", "timeline", "notes", "n"
    ]

    // MARK: - Static Helpers

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://note.com/\(handle)")
    }

    nonisolated static func creatorAPIURL(for handle: String) -> URL? {
        URL(string: "https://note.com/api/v2/creators/\(handle)")
    }

    /// Stricter than `matchesHost` — note.com only serves on bare and `www.`
    /// subdomains.
    nonisolated static func isNoteHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "note.com" || host == "www.note.com"
    }

    nonisolated static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return false }
        return !reservedHandles.contains(handle.lowercased())
    }

    // MARK: - Public

    func fetchProfile(handle: String) async -> NoteProfileFetchResult {
        guard let url = Self.creatorAPIURL(for: handle) else {
            return NoteProfileFetchResult(profileImageURL: nil, displayName: nil)
        }
        return await performFetch(url: url)
    }
}
