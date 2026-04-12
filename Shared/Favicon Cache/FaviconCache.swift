import Foundation
import UIKit

actor FaviconCache {

    static let shared = FaviconCache()

    /// Dedicated URLSession used for every favicon-related network fetch.
    /// Favicons are cosmetic and must not fail just because an image takes
    /// a long time to download, so this session effectively bypasses the
    /// normal request / resource timeouts.
    nonisolated static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    let cacheDirectory: URL
    var memoryCache: [String: UIImage] = [:]
    var failedLookups: Set<String> = []

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        cacheDirectory = containerURL.appendingPathComponent("FaviconCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func favicon(for domain: String, siteURL: String? = nil) async -> UIImage? {
        let cacheKey = Self.cacheKey(domain: domain, siteURL: siteURL)

        if failedLookups.contains(cacheKey) {
            return nil
        }

        if let cached = memoryCache[cacheKey] {
            return cached
        }

        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            let skipTrim = SkipTrimDomains.shouldSkipTrimming(feedDomain: domain)
                || CircleIconDomains.shouldUseCircleIcon(feedDomain: domain)
            let result = skipTrim ? image : await image.trimmed()
            memoryCache[cacheKey] = result
            return result
        }

        return await fetchAndCacheFavicon(for: domain, siteURL: siteURL, cacheKey: cacheKey, filePath: filePath)
    }

    /// Clears caches for the given domains and re-fetches their favicons.
    func refreshFavicons(for entries: [(domain: String, siteURL: String?)]) async {
        for entry in entries {
            let cacheKey = Self.cacheKey(domain: entry.domain, siteURL: entry.siteURL)
            memoryCache[cacheKey] = nil
            failedLookups.remove(cacheKey)
            let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
            try? FileManager.default.removeItem(at: filePath)
        }
        await withTaskGroup(of: Void.self) { group in
            for entry in entries {
                let cacheKey = Self.cacheKey(domain: entry.domain, siteURL: entry.siteURL)
                let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
                group.addTask {
                    _ = await self.fetchAndCacheFavicon(
                        for: entry.domain, siteURL: entry.siteURL,
                        cacheKey: cacheKey, filePath: filePath
                    )
                }
            }
        }
    }

    func clearCache() {
        memoryCache.removeAll()
        failedLookups.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Removes specific entries from the failed-lookups set so they will be
    /// retried on the next request.
    func clearFailedLookups(for entries: [(domain: String, siteURL: String?)]) {
        for entry in entries {
            let cacheKey = Self.cacheKey(domain: entry.domain, siteURL: entry.siteURL)
            failedLookups.remove(cacheKey)
        }
    }

    nonisolated static func cacheKey(domain: String, siteURL: String?) -> String {
        guard isProfileBased(domain: domain, siteURL: siteURL),
              let siteURL = siteURL, let url = URL(string: siteURL) else {
            return domain
        }
        let host = url.host ?? domain
        let path = url.path
        return path.isEmpty ? host : host + path
    }

    func sanitizedFileName(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_") + ".png"
    }
}
