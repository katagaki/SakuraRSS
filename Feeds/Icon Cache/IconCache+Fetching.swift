import UIKit
import FaviconFinder

extension IconCache {

    func trimAndCache(
        _ image: UIImage, cacheKey: String, filePath: URL,
        domain: String? = nil, skipTrim: Bool = false
    ) async -> UIImage {
        let shouldSkipTrim = skipTrim || (domain.map {
            FeedIconCircleDomains.shouldUseCircleIcon(feedDomain: $0)
        } ?? false)
        let result = shouldSkipTrim ? image : await image.trimmed()
        if let pngData = result.pngData() {
            try? pngData.write(to: filePath)
        }
        attachDerivedMetrics(cacheKey: cacheKey, to: result)
        memoryCache[cacheKey] = result
        return result
    }

    func fetchAndCacheIcon(
        for domain: String, siteURL: String? = nil,
        cacheKey: String, filePath: URL
    ) async -> UIImage? {
        log("Icon", "Fetching icon for domain: \(domain), cacheKey: \(cacheKey)")

        if Self.isProfileBased(domain: domain, siteURL: siteURL), let siteURL = siteURL,
           let image = await fetchProfileAvatar(from: siteURL) {
            log("Icon", "Found profile avatar for \(domain)")
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath, domain: domain)
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
            return await trimAndCache(
                image, cacheKey: cacheKey, filePath: filePath, domain: domain, skipTrim: true
            )
        }

        if let touchURL = URL(string: "https://\(iconDomain)/apple-touch-icon.png"),
           let (data, _) = try? await Self.urlSession.data(from: touchURL),
           let image = UIImage(data: data) {
            log("Icon", "Direct apple-touch-icon for \(domain)")
            return await trimAndCache(
                image, cacheKey: cacheKey, filePath: filePath, domain: domain, skipTrim: true
            )
        }

        if let result = await fetchPWAIcon(from: url) {
            log("Icon", "Found PWA/touch icon for \(domain)")
            return await trimAndCache(
                result.image, cacheKey: cacheKey, filePath: filePath,
                domain: domain, skipTrim: result.isAppleTouchIcon
            )
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
            return await trimAndCache(iconImage.image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        } catch {
            log("Icon", "FaviconFinder failed for \(domain): \(error.localizedDescription)")
            recordFailedLookup(cacheKey)
            return nil
        }
    }
}
