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
        // Compute and persist the derived-metrics sidecar next to the PNG
        // so subsequent launches don't need to re-sample the pixels.
        attachDerivedMetrics(cacheKey: cacheKey, to: result)
        memoryCache[cacheKey] = result
        return result
    }

    func fetchAndCacheFavicon(
        for domain: String, siteURL: String? = nil,
        cacheKey: String, filePath: URL
    ) async -> UIImage? {
        #if DEBUG
        debugPrint("[Favicon] Fetching favicon for domain: \(domain), cacheKey: \(cacheKey)")
        #endif

        // For profile-based feeds, fetch the avatar from the profile page's og:image
        if Self.isProfileBased(domain: domain, siteURL: siteURL), let siteURL = siteURL,
           let image = await fetchProfileAvatar(from: siteURL) {
            #if DEBUG
            debugPrint("[Favicon] Found profile avatar for \(domain)")
            #endif
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        }

        // Map feed domains to their favicon domain (e.g. feeds.bbci.co.uk → bbc.co.uk)
        let faviconDomain = FaviconAlternateDomains.faviconDomain(for: domain)
        #if DEBUG
        if faviconDomain != domain {
            debugPrint("[Favicon] Mapped domain \(domain) → \(faviconDomain)")
        }
        #endif

        guard let url = URL(string: "https://\(faviconDomain)") else {
            #if DEBUG
            debugPrint("[Favicon] Invalid domain URL: \(domain)")
            #endif
            failedLookups.insert(cacheKey)
            return nil
        }

        // Try PWA / apple-touch-icon first for higher quality
        if let image = await fetchPWAIcon(from: url) {
            #if DEBUG
            debugPrint("[Favicon] Found PWA/touch icon for \(domain)")
            #endif
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        }

        // Fall back to FaviconFinder
        do {
            let faviconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestFaviconURL = faviconURLs.first else {
                #if DEBUG
                debugPrint("[Favicon] No favicon URLs found for \(domain)")
                #endif
                failedLookups.insert(cacheKey)
                return nil
            }
            #if DEBUG
            debugPrint("[Favicon] Downloading favicon from \(bestFaviconURL) for \(domain)")
            #endif
            let favicon = try await bestFaviconURL.download()
            guard let faviconImage = favicon.image else {
                #if DEBUG
                debugPrint("[Favicon] Failed to decode favicon image for \(domain)")
                #endif
                failedLookups.insert(cacheKey)
                return nil
            }
            return await trimAndCache(faviconImage.image, cacheKey: cacheKey, filePath: filePath, domain: domain)
        } catch {
            #if DEBUG
            debugPrint("[Favicon] FaviconFinder failed for \(domain): \(error.localizedDescription)")
            #endif
            failedLookups.insert(cacheKey)
            return nil
        }
    }
}
