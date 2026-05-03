import UIKit
import FaviconFinder

extension IconCache {

    func cache(_ image: UIImage, cacheKey: String, filePath: URL) -> UIImage {
        if let pngData = image.pngData() {
            try? pngData.write(to: filePath)
        }
        attachDerivedMetrics(cacheKey: cacheKey, to: image)
        memoryCache[cacheKey] = image
        return image
    }

    func fetchAndCacheIcon(
        for domain: String, siteURL: String? = nil,
        cacheKey: String, filePath: URL
    ) async -> UIImage? {
        log("Icon", "Fetching icon for domain: \(domain), cacheKey: \(cacheKey)")

        if Self.isProfileBased(domain: domain, siteURL: siteURL), let siteURL = siteURL,
           let image = await fetchProfileAvatar(from: siteURL) {
            log("Icon", "Found profile avatar for \(domain)")
            return cache(image, cacheKey: cacheKey, filePath: filePath)
        }

        let iconDomain = FeedIconAlternateDomains.iconDomain(for: domain)
        if iconDomain != domain {
            log("Icon", "Mapped domain \(domain) → \(iconDomain)")
        }

        guard let url = URL(string: "https://\(iconDomain)") else {
            log("Icon", "Invalid domain URL: \(domain)")
            recordFailedLookup(cacheKey)
            return nil
        }

        if let image = await fetchAppleTouchIcon(from: url) {
            log("Icon", "Found HTML apple-touch-icon for \(domain)")
            return cache(image, cacheKey: cacheKey, filePath: filePath)
        }

        if let touchURL = URL(string: "https://\(iconDomain)/apple-touch-icon.png"),
           let (data, _) = try? await Self.urlSession.data(from: touchURL),
           let image = UIImage(data: data) {
            log("Icon", "Direct apple-touch-icon for \(domain)")
            return cache(image, cacheKey: cacheKey, filePath: filePath)
        }

        if let image = await fetchPWAIcon(from: url) {
            log("Icon", "Found PWA/touch icon for \(domain)")
            return cache(image, cacheKey: cacheKey, filePath: filePath)
        }

        do {
            let iconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestIconURL = iconURLs.first else {
                log("Icon", "No icon URLs found for \(domain)")
                recordFailedLookup(cacheKey)
                return nil
            }
            log("Icon", "Downloading icon from \(bestIconURL) for \(domain)")
            let icon = try await bestIconURL.download()
            guard let iconImage = icon.image else {
                log("Icon", "Failed to decode icon image for \(domain)")
                recordFailedLookup(cacheKey)
                return nil
            }
            return cache(iconImage.image, cacheKey: cacheKey, filePath: filePath)
        } catch {
            log("Icon", "FaviconFinder failed for \(domain): \(error.localizedDescription)")
            recordFailedLookup(cacheKey)
            return nil
        }
    }
}
