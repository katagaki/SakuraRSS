import Foundation
import UIKit

actor FaviconCache {

    static let shared = FaviconCache()

    /// Dedicated short-timeout URLSession for favicon fetches.
    nonisolated static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["User-Agent": sakuraUserAgent]
        return URLSession(configuration: config)
    }()

    let cacheDirectory: URL
    var memoryCache: [String: UIImage] = [:]
    var failedLookups: [String: Date] = [:]

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        cacheDirectory = containerURL.appendingPathComponent("FaviconCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let failedLookupsURL = cacheDirectory.appendingPathComponent(Self.failedLookupsFileName)
        failedLookups = Self.loadFailedLookupsFromDisk(at: failedLookupsURL)
    }

    func favicon(for domain: String, siteURL: String? = nil) async -> UIImage? {
        let cacheKey = Self.cacheKey(domain: domain, siteURL: siteURL)

        if isWithinFailureTTL(cacheKey) {
            return nil
        }

        if let cached = memoryCache[cacheKey] {
            return cached
        }

        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            let skipTrim = FaviconSkipTrimDomains.shouldSkipTrimming(feedDomain: domain)
                || FaviconCircularDomains.shouldUseCircleIcon(feedDomain: domain)
            let result = skipTrim ? image : await image.trimmed()
            attachDerivedMetrics(cacheKey: cacheKey, to: result)
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
            forgetFailedLookup(cacheKey)
            let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
            try? FileManager.default.removeItem(at: filePath)
            try? FileManager.default.removeItem(at: metricsSidecarURL(for: cacheKey))
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
        forgetAllFailedLookups()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Removes specific entries from the failed-lookups set to be retried.
    func clearFailedLookups(for entries: [(domain: String, siteURL: String?)]) {
        for entry in entries {
            let cacheKey = Self.cacheKey(domain: entry.domain, siteURL: entry.siteURL)
            forgetFailedLookup(cacheKey)
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

    // MARK: - Derived Metrics Sidecar

    /// Returns the JSON sidecar URL for a cached favicon's derived metrics.
    func metricsSidecarURL(for cacheKey: String) -> URL {
        cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey) + ".meta.json")
    }

    /// Attaches cached metrics to the image, computing and persisting them if missing.
    func attachDerivedMetrics(cacheKey: String, to image: UIImage) {
        let url = metricsSidecarURL(for: cacheKey)
        if let data = try? Data(contentsOf: url),
           let metrics = try? JSONDecoder().decode(FaviconDerivedMetrics.self, from: data) {
            image.faviconDerivedMetrics = metrics
            return
        }
        let metrics = image.ensureFaviconDerivedMetrics()
        if let data = try? JSONEncoder().encode(metrics) {
            try? data.write(to: url)
        }
    }
}
