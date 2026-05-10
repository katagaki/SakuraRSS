import Foundation

/// Fetches Bluesky profile metadata by scraping the public profile page.
final class BlueskyProvider {

    nonisolated static let host = "bsky.app"

    nonisolated static let reservedHandles: Set<String> = [
        "search", "notifications", "settings", "feeds", "lists",
        "messages", "starter-pack", "starter-pack-short",
        "hashtag", "support", "intent"
    ]

    // MARK: - Static Helpers

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://bsky.app/profile/\(handle)")
    }

    nonisolated static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return false }
        return !reservedHandles.contains(handle.lowercased())
    }

    // MARK: - Public

    func fetchProfile(handle: String) async -> BlueskyProfileFetchResult {
        await performFetch(handle: handle)
    }
}
