import SwiftUI

extension FeedEditMetadataTab {

    func loadCurrentFavicon() async -> UIImage? {
        guard let feed else { return nil }
        if let customURL = feed.customIconURL {
            if customURL == "none" {
                return nil
            }
            if customURL == "photo" {
                return await FaviconCache.shared.customFavicon(feedID: feed.id)
            }
            if let cached = await FaviconCache.shared.customFavicon(feedID: feed.id) {
                return cached
            }
            if let url = URL(string: customURL),
               let (data, _) = try? await URLSession.shared.data(for: .sakuraImage(url: url)),
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
        guard let feed else { return }
        isFetchingIcon = true
        defer { isFetchingIcon = false }

        if feed.isXFeed,
           let handle = XProfileFetcher.identifierFromFeedURL(feed.url),
           let cookies = await XProfileFetcher.getXCookies() {
            let fetcher = XProfileFetcher()
            if let userInfo = await fetcher.fetchUserInfo(screenName: handle, cookies: cookies),
               let imageURLString = userInfo.profileImageURL,
               let imageURL = URL(string: imageURLString),
               let (data, _) = try? await URLSession.shared.data(for: .sakuraImage(url: imageURL)),
               let image = UIImage(data: data) {
                customIconImage = image
                currentFavicon = image
                selectedPhoto = nil
                iconURLInput = ""
                useDefaultIcon = false
                return
            }
        }

        if feed.isInstagramFeed,
           let handle = InstagramProfileFetcher.identifierFromFeedURL(feed.url),
           let profileURL = InstagramProfileFetcher.profileURL(for: handle) {
            let fetcher = InstagramProfileFetcher()
            let result = await fetcher.fetchProfile(profileURL: profileURL)
            if let imageURLString = result.profileImageURL,
               let imageURL = URL(string: imageURLString),
               let (data, _) = try? await URLSession.shared.data(for: .sakuraImage(url: imageURL)),
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
            let (data, _) = try await URLSession.shared.data(for: .sakuraImage(url: url))
            if let image = UIImage(data: data) {
                customIconImage = image.trimmed()
                selectedPhoto = nil
                useDefaultIcon = false
                return true
            }
        } catch {
        }
        showIconFetchError = true
        return false
    }
}
