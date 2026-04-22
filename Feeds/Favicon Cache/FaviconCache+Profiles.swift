import UIKit

extension FaviconCache {

    /// Domains where each feed represents a unique profile and
    /// the profile page's og:image should be used as the favicon.
    static func isProfileBasedDomain(_ domain: String) -> Bool {
        let host = domain.lowercased()
        if host.contains("youtube.com") || host.contains("youtu.be") { return true }
        if host == "bsky.app" || host.hasSuffix(".bsky.app") { return true }
        if host == "reddit.com" || host.hasSuffix(".reddit.com") { return true }
        if host == "note.com" || host.hasSuffix(".note.com") { return true }
        if DisplayStyleFeedDomains.shouldPreferFeedView(feedDomain: host) { return true }
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

    /// Fetches a note.com creator's profile photo via the public v2
    /// creators API. note.com doesn't expose a usable og:image on the
    /// profile page, so we pull it from `/api/v2/creators/<urlname>`.
    nonisolated func fetchNoteProfileAvatar(handle: String) async -> UIImage? {
        let scraper = NoteProfileScraper()
        let result = await scraper.scrapeProfile(handle: handle)
        guard let imageURLString = result.profileImageURL,
              let imageURL = URL(string: imageURLString),
              let (data, _) = try? await Self.urlSession.data(from: imageURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Fetches a subreddit's community icon via the Reddit Community Scraper.
    /// Reddit doesn't expose the styled community icon through og:image,
    /// so we pull it from `/r/<name>/about.json`.
    nonisolated func fetchRedditCommunityIcon(subreddit: String) async -> UIImage? {
        let scraper = RedditCommunityScraper()
        let result = await scraper.scrapeCommunity(subreddit: subreddit)
        guard let iconURLString = result.communityIconURL,
              let iconURL = URL(string: iconURLString),
              let (data, _) = try? await Self.urlSession.data(from: iconURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Fetches a profile avatar by scraping the profile page for the og:image meta tag.
    /// Works for YouTube channels, Mastodon profiles, and Bluesky profiles.
    /// Subreddits are handled via the Reddit Community Scraper instead.
    nonisolated func fetchProfileAvatar(from siteURL: String) async -> UIImage? {
        guard let url = URL(string: siteURL) else { return nil }
        if RedditCommunityScraper.isRedditSubredditURL(url),
           let subreddit = RedditCommunityScraper.extractSubredditName(from: url) {
            return await fetchRedditCommunityIcon(subreddit: subreddit)
        }
        if NoteProfileScraper.isNoteProfileURL(url),
           let handle = NoteProfileScraper.extractHandle(from: url) {
            return await fetchNoteProfileAvatar(handle: handle)
        }
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
