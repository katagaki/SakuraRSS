import UIKit
import FaviconFinder

extension FaviconCache {

    func trimAndCache(_ image: UIImage, cacheKey: String, filePath: URL, domain: String? = nil) async -> UIImage {
        let skipTrim = domain.map {
            FaviconSkipTrimDomains.shouldSkipTrimming(feedDomain: $0)
                || FaviconCircularDomains.shouldUseCircleIcon(feedDomain: $0)
        } ?? false
        let result = skipTrim ? image : await image.trimmed()
        if let pngData = result.pngData() {
            try? pngData.write(to: filePath)
        }
        attachDerivedMetrics(cacheKey: cacheKey, to: result)
        memoryCache[cacheKey] = result
        return result
    }

    func fetchAndCacheFavicon(
        for domain: String, siteURL: String? = nil,
        cacheKey: String, filePath: URL
    ) async -> UIImage? {
        log("Favicon", "Fetching favicon for domain: \(domain), cacheKey: \(cacheKey)")

        if Self.isProfileBased(domain: domain, siteURL: siteURL), let siteURL = siteURL,
           let image = await fetchProfileAvatar(from: siteURL) {
            log("Favicon", "Found profile avatar for \(domain)")
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        }

        let faviconDomain = FaviconAlternateDomains.faviconDomain(for: domain)
        if faviconDomain != domain {
            log("Favicon", "Mapped domain \(domain) → \(faviconDomain)")
        }

        guard let url = URL(string: "https://\(faviconDomain)") else {
            log("Favicon", "Invalid domain URL: \(domain)")
            recordFailedLookup(cacheKey)
            return nil
        }

        if FaviconForceAppleTouchIconDomains.shouldForceAppleTouchIcon(feedDomain: faviconDomain),
           let touchURL = URL(string: "https://\(faviconDomain)/apple-touch-icon.png"),
           let (data, _) = try? await Self.urlSession.data(from: touchURL),
           let image = UIImage(data: data) {
            log("Favicon", "Forced apple-touch-icon for \(domain)")
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        }

        if let image = await fetchPWAIcon(from: url) {
            log("Favicon", "Found PWA/touch icon for \(domain)")
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        }

        do {
            let faviconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestFaviconURL = faviconURLs.first else {
                log("Favicon", "No favicon URLs found for \(domain)")
                recordFailedLookup(cacheKey)
                return nil
            }
            log("Favicon", "Downloading favicon from \(bestFaviconURL) for \(domain)")
            let favicon = try await bestFaviconURL.download()
            guard let faviconImage = favicon.image else {
                log("Favicon", "Failed to decode favicon image for \(domain)")
                recordFailedLookup(cacheKey)
                return nil
            }
            return await trimAndCache(faviconImage.image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        } catch {
            log("Favicon", "FaviconFinder failed for \(domain): \(error.localizedDescription)")
            recordFailedLookup(cacheKey)
            return nil
        }
    }
}
