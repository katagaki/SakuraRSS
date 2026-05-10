import Foundation

/// Fetches Bluesky profile metadata by scraping the public profile page.
public final class BlueskyProvider {

    public nonisolated static let host = "bsky.app"

    public nonisolated static let reservedHandles: Set<String> = [
        "search", "notifications", "settings", "feeds", "lists",
        "messages", "starter-pack", "starter-pack-short",
        "hashtag", "support", "intent"
    ]
    public nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://bsky.app/profile/\(handle)")
    }

    public nonisolated static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return false }
        return !reservedHandles.contains(handle.lowercased())
    }
    public func fetchProfile(handle: String) async -> BlueskyProfileFetchResult {
        await performFetch(handle: handle)
    }
}
