import SwiftUI

extension FeedEditSheet {

    func loadCurrentFavicon() async -> UIImage? {
        if let customURL = feed.customIconURL {
            if customURL == "none" {
                return nil
            }
            if customURL == "photo" {
                return await FaviconCache.shared.customFavicon(feedID: feed.id)
            }
            // Check if already cached for this feed
            if let cached = await FaviconCache.shared.customFavicon(feedID: feed.id) {
                return cached
            }
            // Download, cache locally, then return
            if let url = URL(string: customURL),
               let (data, _) = try? await URLSession.shared.data(for: .sakura(url: url)),
               let image = UIImage(data: data) {
                await FaviconCache.shared.setCustomFavicon(image, feedID: feed.id)
                return image
            }
        }
        return await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
    }

    func iconCornerRadius(size: CGFloat) -> CGFloat {
        size / 8
    }

    func fetchIconFromFeed() async {
        isFetchingIcon = true
        defer { isFetchingIcon = false }

        // For X feeds, fetch the profile avatar using XProfileScraper
        if feed.isXFeed,
           let handle = XProfileScraper.handleFromFeedURL(feed.url),
           let cookies = await XProfileScraper.getXCookies() {
            let scraper = XProfileScraper()
            if let userInfo = await scraper.fetchUserInfo(screenName: handle, cookies: cookies),
               let imageURLString = userInfo.profileImageURL,
               let imageURL = URL(string: imageURLString),
               let (data, _) = try? await URLSession.shared.data(for: .sakura(url: imageURL)),
               let image = UIImage(data: data) {
                customIconImage = image
                currentFavicon = image
                selectedPhoto = nil
                iconURLInput = ""
                useDefaultIcon = false
                return
            }
        }

        // For Instagram feeds, fetch the profile avatar using InstagramProfileScraper
        if feed.isInstagramFeed,
           let handle = InstagramProfileScraper.handleFromFeedURL(feed.url),
           let profileURL = InstagramProfileScraper.profileURL(for: handle) {
            let scraper = InstagramProfileScraper()
            let result = await scraper.scrapeProfile(profileURL: profileURL)
            if let imageURLString = result.profileImageURL,
               let imageURL = URL(string: imageURLString),
               let (data, _) = try? await URLSession.shared.data(for: .sakura(url: imageURL)),
               let image = UIImage(data: data) {
                customIconImage = image
                currentFavicon = image
                selectedPhoto = nil
                iconURLInput = ""
                useDefaultIcon = false
                return
            }
        }

        await FaviconCache.shared.refreshFavicons(for: [(domain: feed.domain, siteURL: feed.siteURL)])
        if let image = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL) {
            customIconImage = image
            currentFavicon = image
            selectedPhoto = nil
            iconURLInput = ""
            useDefaultIcon = false
        }
    }

    @discardableResult
    func fetchIconFromURL() async -> Bool {
        let input = iconURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: input), url.scheme != nil else {
            showIconFetchError = true
            return false
        }
        isFetchingIcon = true
        defer { isFetchingIcon = false }
        do {
            let (data, _) = try await URLSession.shared.data(for: .sakura(url: url))
            if let image = UIImage(data: data) {
                customIconImage = image.trimmed()
                selectedPhoto = nil
                useDefaultIcon = false
                return true
            }
        } catch {
            // Icon fetch failed — show error below
        }
        showIconFetchError = true
        return false
    }
}
