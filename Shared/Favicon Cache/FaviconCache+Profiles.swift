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

    /// Fetches an X (Twitter) profile avatar using the XProfileScraper API.
    /// Uses a long request timeout since favicons are cosmetic and should
    /// not fail when the network is slow.
    nonisolated func fetchXProfileAvatar(handle: String) async -> UIImage? {
        let scraper = XProfileScraper()
        scraper.requestTimeoutInterval = 600
        guard let cookies = await XProfileScraper.getXCookies(),
              let userInfo = await scraper.fetchUserInfo(screenName: handle, cookies: cookies),
              let imageURLString = userInfo.profileImageURL,
              let imageURL = URL(string: imageURLString),
              let (data, _) = try? await Self.urlSession.data(from: imageURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Fetches an Instagram profile avatar using the InstagramProfileScraper API.
    /// Uses a long request timeout since favicons are cosmetic and should
    /// not fail when the network is slow.
    nonisolated func fetchInstagramProfileAvatar(handle: String) async -> UIImage? {
        guard let profileURL = InstagramProfileScraper.profileURL(for: handle) else { return nil }
        let scraper = InstagramProfileScraper()
        scraper.requestTimeoutInterval = 600
        let result = await scraper.scrapeProfile(profileURL: profileURL)
        guard let imageURLString = result.profileImageURL,
              let imageURL = URL(string: imageURLString),
              let (data, _) = try? await Self.urlSession.data(from: imageURL) else {
            return nil
        }
        return UIImage(data: data)
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
