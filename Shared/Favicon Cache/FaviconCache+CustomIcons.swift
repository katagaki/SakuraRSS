import UIKit

extension FaviconCache {

    /// Resolves the favicon for a feed, checking custom icons first.
    func favicon(for feed: Feed) async -> UIImage? {
        if let customURL = feed.customIconURL {
            if customURL == "none" {
                return nil
            }
            if customURL == "photo" {
                return customFavicon(feedID: feed.id)
            }
            if let cached = customFavicon(feedID: feed.id) {
                return cached
            }
            if let url = URL(string: customURL),
               let (data, _) = try? await Self.urlSession.data(from: url),
               let image = UIImage(data: data) {
                await setCustomFavicon(image, feedID: feed.id)
                return image
            }
        }

        // For X feeds without a cached photo, fetch the profile avatar via XProfileScraper
        if feed.isXFeed,
           let handle = XProfileScraper.handleFromFeedURL(feed.url),
           let image = await fetchXProfileAvatar(handle: handle) {
            await setCustomFavicon(image, feedID: feed.id, skipTrimming: true)
            return image
        }

        // For Instagram feeds without a cached photo, fetch the profile avatar
        if feed.isInstagramFeed,
           let handle = InstagramProfileScraper.handleFromFeedURL(feed.url),
           let image = await fetchInstagramProfileAvatar(handle: handle) {
            await setCustomFavicon(image, feedID: feed.id, skipTrimming: true)
            return image
        }

        return await favicon(for: feed.domain, siteURL: feed.siteURL)
    }

    func setCustomFavicon(_ image: UIImage, feedID: Int64, skipTrimming: Bool = false) async {
        let finalImage = skipTrimming ? image : await image.trimmed()
        let key = "custom-feed-\(feedID)"
        memoryCache[key] = finalImage
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        if let pngData = finalImage.pngData() {
            try? pngData.write(to: filePath)
        }
    }

    func customFavicon(feedID: Int64) -> UIImage? {
        let key = "custom-feed-\(feedID)"
        if let cached = memoryCache[key] {
            return cached
        }
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache[key] = image
            return image
        }
        return nil
    }

    func removeCustomFavicon(feedID: Int64) {
        let key = "custom-feed-\(feedID)"
        memoryCache[key] = nil
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        try? FileManager.default.removeItem(at: filePath)
    }
}
