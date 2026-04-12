import UIKit

extension FaviconCache {

    /// Domains where each feed represents a unique profile and
    /// the profile page's og:image should be used as the favicon.
    static func isProfileBasedDomain(_ domain: String) -> Bool {
        let host = domain.lowercased()
        if host.contains("youtube.com") || host.contains("youtu.be") { return true }
        if host == "bsky.app" || host.hasSuffix(".bsky.app") { return true }
        if FeedViewDomains.shouldPreferFeedView(feedDomain: host) { return true }
        return false
    }

    /// Checks domain or siteURL pattern to detect profile-based feeds,
    /// including Mastodon instances not in the allowlist.
    static func isProfileBased(domain: String, siteURL: String?) -> Bool {
        if isProfileBasedDomain(domain) { return true }
        // Detect unlisted Mastodon instances by /@username path pattern
        if let siteURL, let url = URL(string: siteURL), url.path.hasPrefix("/@") {
            return true
        }
        return false
    }

    /// Fetches a profile avatar by scraping the profile page for the og:image meta tag.
    /// Works for YouTube channels, Mastodon profiles, and Bluesky profiles.
    nonisolated func fetchProfileAvatar(from siteURL: String) async -> UIImage? {
        guard let url = URL(string: siteURL) else { return nil }
        do {
            let (data, _) = try await Self.urlSession.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            guard let imageURL = extractMetaContent(from: html, property: "og:image"),
                  let avatarURL = URL(string: imageURL) else { return nil }

            let (imageData, _) = try await Self.urlSession.data(from: avatarURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }
}
