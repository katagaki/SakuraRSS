import SwiftUI

extension FeedEditSheet {

    func loadCurrentFavicon() async -> UIImage? {
        // Delegate to FaviconCache so we share the same resolution logic
        // (cached custom icon → integration profile photo → domain favicon).
        // This avoids duplicating the "photo was cleared, re-fetch via
        // integration" fallback in two places.
        return await FaviconCache.shared.favicon(for: feed)
    }

    func iconCornerRadius(size: CGFloat) -> CGFloat {
        if feed.isPodcast { return size / 4 }
        if feed.isVideoFeed { return 0 }
        return size / 8
    }

    func fetchIconFromFeed() async {
        isFetchingIcon = true
        defer { isFetchingIcon = false }

        // For integration feeds (X, Instagram, …), fetch the profile photo
        // through the integration. Each integration knows how to resolve a
        // pseudo-feed URL to an image without the caller dealing with
        // cookies, handles, or per-platform APIs.
        if let integration = IntegrationRegistry.integration(forFeedURL: feed.url),
           type(of: integration).supportsProfilePhoto,
           let image = await integration.fetchProfilePhoto(forFeedURL: feed.url) {
            await FaviconCache.shared.setCustomFavicon(
                image, feedID: feed.id, skipTrimming: true
            )
            customIconImage = nil
            currentFavicon = image
            selectedPhoto = nil
            iconURLInput = ""
            useDefaultIcon = false
            return
        }

        await FaviconCache.shared.refreshFavicons(for: [(domain: feed.domain, siteURL: feed.siteURL)])
        if let image = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL) {
            customIconImage = nil
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
            let (data, _) = try await URLSession.shared.data(from: url)
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
