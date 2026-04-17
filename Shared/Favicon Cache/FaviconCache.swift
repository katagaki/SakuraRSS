import Foundation
import UIKit

actor FaviconCache {

    static let shared = FaviconCache()

    /// Dedicated URLSession used for every favicon-related network fetch.
    /// Favicons are cosmetic, and hanging on a slow or unreachable host
    /// keeps a request slot — and radio time — alive for far longer than
    /// a missing icon is worth.  Keep the timeouts tight (3 seconds) and
    /// disable `waitsForConnectivity` so we never sit on a request while
    /// the device is offline.  `httpAdditionalHeaders` sets a Safari-parity
    /// User-Agent on every request so the default `CFNetwork` UA (which
    /// leaks the app bundle ID and iOS version) is never sent.
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
    /// Hosts whose favicon fetch most recently failed, keyed by cacheKey.
    /// Persisted to disk with a 24h TTL — see `FaviconCache+FailedLookups`.
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

    /// Removes specific entries from the failed-lookups set so they will be
    /// retried on the next request.
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

    /// JSON sidecar URL holding FaviconDerivedMetrics for a cached favicon.
    /// Stored next to the PNG so `refreshFavicons`/`clearCache` wipe both
    /// together by iterating the directory.
    func metricsSidecarURL(for cacheKey: String) -> URL {
        cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey) + ".meta.json")
    }

    /// Attaches the cached metrics to the image.  If the sidecar already
    /// exists on disk it's decoded and attached as-is; otherwise the
    /// metrics are computed from the pixels now and the sidecar is
    /// written, so subsequent app launches avoid the pixel sampling
    /// work entirely.
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
