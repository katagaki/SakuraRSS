import Foundation

// MARK: - X (Twitter) URL Helpers

/// Pure URL-matching helpers for X/Twitter. Lives in `Shared/` so that
/// cross-target files (`Models.swift`, `FeedDiscovery.swift`) can call
/// these without depending on the app-only `XIntegration` class.
///
/// Every member is `nonisolated` so the helpers can be called from any
/// actor context — including the non-main-actor `Models.swift` and the
/// `FeedDiscovery` actor — under Swift 6's default-main-actor isolation.
enum XURLHelpers {

    nonisolated static let feedURLScheme = "x-profile://"

    /// Returns true if the URL points to a specific X/Twitter post (status).
    nonisolated static func isXPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isXDomain = host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
        guard isXDomain else { return false }
        // Path like /username/status/1234567890
        let components = url.pathComponents
        return components.count >= 4 && components[2] == "status"
    }

    /// Extracts the tweet ID from an X/Twitter status URL.
    nonisolated static func extractTweetID(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count >= 4, components[2] == "status" else { return nil }
        return components[3]
    }

    /// Returns true if the URL points to an X/Twitter profile.
    nonisolated static func isXProfileURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isXDomain = host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
        guard isXDomain else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "home", "explore", "search", "notifications", "messages",
            "settings", "login", "signup", "i", "intent", "hashtag",
            "compose", "tos", "privacy"
        ]
        return !reserved.contains(handle.lowercased())
    }

    /// Extracts the username handle from an X profile URL.
    nonisolated static func extractHandle(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    /// Constructs a canonical X profile URL from a handle.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://x.com/\(handle)")
    }

    /// The pseudo-feed URL stored in the database for an X profile.
    nonisolated static func feedURL(for handle: String) -> String {
        "\(feedURLScheme)\(handle.lowercased())"
    }

    /// Checks if a feed URL is an X pseudo-feed.
    nonisolated static func isXFeedURL(_ url: String) -> Bool {
        url.hasPrefix(feedURLScheme)
    }

    /// Extracts the handle from an X pseudo-feed URL.
    nonisolated static func handleFromFeedURL(_ url: String) -> String? {
        guard isXFeedURL(url) else { return nil }
        return String(url.dropFirst(feedURLScheme.count))
    }
}

// MARK: - Instagram URL Helpers

/// Pure URL-matching helpers for Instagram.
enum InstagramURLHelpers {

    nonisolated static let feedURLScheme = "instagram-profile://"

    /// Returns true if the URL points to a specific Instagram post.
    nonisolated static func isInstagramPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isInstagramDomain = host == "instagram.com" || host == "www.instagram.com"
        guard isInstagramDomain else { return false }
        let components = url.pathComponents
        // /p/SHORTCODE/ or /reel/SHORTCODE/
        return components.count >= 3
            && (components[1] == "p" || components[1] == "reel")
    }

    /// Returns true if the URL points to an Instagram profile.
    nonisolated static func isInstagramProfileURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isInstagramDomain = host == "instagram.com" || host == "www.instagram.com"
        guard isInstagramDomain else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "explore", "accounts", "p", "reel", "reels", "stories",
            "direct", "about", "legal", "developer", "api",
            "static", "emails", "challenge", "nux", "graphql"
        ]
        return !reserved.contains(handle.lowercased())
    }

    /// Extracts the username handle from an Instagram profile URL.
    nonisolated static func extractHandle(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    /// Constructs a canonical Instagram profile URL from a handle.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://www.instagram.com/\(handle)/")
    }

    /// The pseudo-feed URL stored in the database for an Instagram profile.
    nonisolated static func feedURL(for handle: String) -> String {
        "\(feedURLScheme)\(handle.lowercased())"
    }

    /// Checks if a feed URL is an Instagram pseudo-feed.
    nonisolated static func isInstagramFeedURL(_ url: String) -> Bool {
        url.hasPrefix(feedURLScheme)
    }

    /// Extracts the handle from an Instagram pseudo-feed URL.
    nonisolated static func handleFromFeedURL(_ url: String) -> String? {
        guard isInstagramFeedURL(url) else { return nil }
        return String(url.dropFirst(feedURLScheme.count))
    }
}

// MARK: - YouTube Playlist URL Helpers

/// Pure URL-matching helpers for YouTube playlists.
enum YouTubePlaylistURLHelpers {

    nonisolated static let feedURLScheme = "youtube-playlist://"

    /// Returns true if the URL points to a YouTube playlist.
    nonisolated static func isYouTubePlaylistURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isYouTubeDomain = host == "youtube.com" || host == "www.youtube.com"
            || host == "m.youtube.com"
        guard isYouTubeDomain else { return false }
        guard url.path == "/playlist" || url.path == "/playlist/" else { return false }
        return extractPlaylistID(from: url) != nil
    }

    /// Extracts the playlist ID from a YouTube playlist URL.
    nonisolated static func extractPlaylistID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first { $0.name == "list" }?.value
    }

    /// The pseudo-feed URL stored in the database for a YouTube playlist.
    nonisolated static func feedURL(for playlistID: String) -> String {
        "\(feedURLScheme)\(playlistID)"
    }

    /// Constructs the canonical YouTube playlist URL from a playlist ID.
    nonisolated static func playlistURL(for playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

    /// Checks if a feed URL is a YouTube playlist pseudo-feed.
    nonisolated static func isYouTubePlaylistFeedURL(_ url: String) -> Bool {
        url.hasPrefix(feedURLScheme)
    }

    /// Extracts the playlist ID from a YouTube playlist pseudo-feed URL.
    nonisolated static func playlistIDFromFeedURL(_ url: String) -> String? {
        guard isYouTubePlaylistFeedURL(url) else { return nil }
        return String(url.dropFirst(feedURLScheme.count))
    }
}
