import UIKit

extension FaviconCache {

    /// Resolves the favicon for a feed, checking custom icons first.
    func favicon(for feed: Feed) async -> UIImage? {
        if let customURL = feed.customIconURL {
            if customURL == "none" {
                return nil
            }
            if customURL == "photo" {
                if let cached = customFavicon(feedID: feed.id) {
                    return cached
                }
                // The feed is marked as using a profile photo but the
                // cache was cleared. Fall through to the integration fetch
                // below so the photo is re-downloaded on demand.
            } else {
                if let cached = customFavicon(feedID: feed.id) {
                    return cached
                }
                if let url = URL(string: customURL),
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    await setCustomFavicon(image, feedID: feed.id)
                    return image
                }
            }
        }

        // For integration feeds without a cached photo, ask the integration
        // to fetch the profile avatar. The integration knows how to resolve
        // its own pseudo-feed URL and handle authentication.
        if let integration = IntegrationRegistry.integration(forFeedURL: feed.url),
           type(of: integration).supportsProfilePhoto,
           let image = await integration.fetchProfilePhoto(forFeedURL: feed.url) {
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
