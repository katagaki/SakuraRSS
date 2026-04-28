import UIKit

extension FaviconCache {

    /// Checks whether the domain's feeds represent unique profiles that use og:image as favicon.
    static func isProfileBasedDomain(_ domain: String) -> Bool {
        let host = domain.lowercased()
        if host.contains("youtube.com") || host.contains("youtu.be") { return true }
        if host == "bsky.app" || host.hasSuffix(".bsky.app") { return true }
        if host == "reddit.com" || host.hasSuffix(".reddit.com") { return true }
        if host == "note.com" || host.hasSuffix(".note.com") { return true }
        if SubstackPublicationScraper.isSubstackPublicationHost(host) { return true }
        if DisplayStyleFeedDomains.shouldPreferFeedView(feedDomain: host) { return true }
        return false
    }

    /// Detects profile-based feeds including unlisted Mastodon instances.
    static func isProfileBased(domain: String, siteURL: String?) -> Bool {
        if isProfileBasedDomain(domain) { return true }
        if let siteURL, let url = URL(string: siteURL), url.path.hasPrefix("/@") {
            return true
        }
        return false
    }

    /// Fetches an X (Twitter) profile avatar via XProfileScraper.
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

    /// Fetches an Instagram profile avatar via InstagramProfileScraper.
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

    /// Fetches a note.com creator's profile photo via the public creators API.
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

    /// Fetches a subreddit's community icon via RedditCommunityScraper.
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

    /// Fetches a Substack publication's logo via the public publication API.
    nonisolated func fetchSubstackPublicationLogo(host: String) async -> UIImage? {
        let scraper = SubstackPublicationScraper()
        let result = await scraper.scrapePublication(host: host)
        guard let logoURLString = result.logoURL,
              let logoURL = URL(string: logoURLString),
              let (data, _) = try? await Self.urlSession.data(from: logoURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Fetches a profile avatar by scraping the profile page's og:image meta tag.
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
        if SubstackPublicationScraper.isSubstackPublicationURL(url),
           let host = url.host,
           let image = await fetchSubstackPublicationLogo(host: host) {
            return image
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
