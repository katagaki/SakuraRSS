import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension Iconography {

    /// Resolves the icon for a feed, checking custom icons first.
    func icon(for feed: Feed) async -> PlatformImage? {
        if let customURL = feed.customIconURL {
            if customURL == "none" {
                return nil
            }
            if customURL == "photo" {
                return customIcon(feedID: feed.id)
            }
            if let cached = customIcon(feedID: feed.id) {
                return cached
            }
            if let url = URL(string: customURL),
               let (data, _) = try? await Self.urlSession.data(from: url),
               let image = PlatformImage(data: data) {
                setCustomIcon(image, feedID: feed.id)
                return image
            }
        }

        if feed.isXFeed || feed.isInstagramFeed,
           let siteURL = URL(string: feed.siteURL),
           let provider = FeedProviderRegistry.metadataFetcher(forSiteURL: siteURL),
           let metadata = await provider.fetchMetadata(for: siteURL),
           let iconURL = metadata.iconURL,
           let image = await downloadImage(from: iconURL) {
            setCustomIcon(image, feedID: feed.id)
            return image
        }

        return await icon(for: feed.domain, siteURL: feed.siteURL)
    }

    func setCustomIcon(_ image: PlatformImage, feedID: Int64) {
        let key = "custom-feed-\(feedID)"
        memoryCache[key] = image
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        if let pngData = image.pngData() {
            try? pngData.write(to: filePath)
        }
        attachDerivedMetrics(cacheKey: key, to: image)
    }

    func customIcon(feedID: Int64) -> PlatformImage? {
        let key = "custom-feed-\(feedID)"
        if let cached = memoryCache[key] {
            return cached
        }
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        if let data = try? Data(contentsOf: filePath),
           let image = PlatformImage(data: data) {
            attachDerivedMetrics(cacheKey: key, to: image)
            memoryCache[key] = image
            return image
        }
        return nil
    }

    func removeCustomIcon(feedID: Int64) {
        let key = "custom-feed-\(feedID)"
        memoryCache[key] = nil
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        try? FileManager.default.removeItem(at: filePath)
        try? FileManager.default.removeItem(at: metricsSidecarURL(for: key))
    }
}
