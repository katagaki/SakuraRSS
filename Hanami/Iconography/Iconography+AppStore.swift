import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension Iconography {
    nonisolated static let appStoreIconTTL: TimeInterval = 30 * 24 * 60 * 60

    func appStoreIcon(appID: Int) async -> PlatformImage? {
        let cacheKey = "app-store-\(appID)"
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        let cachedImage = cachedAppStoreIcon(cacheKey: cacheKey, filePath: filePath)
        let fetchedAt = appStoreIconDates[cacheKey]
            ?? (try? filePath.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let fetchedAt, let cachedImage, Date().timeIntervalSince(fetchedAt) < Self.appStoreIconTTL {
            appStoreIconDates[cacheKey] = fetchedAt
            return cachedImage
        }
        if isWithinFailureTTL(cacheKey) { return cachedImage }
        if let pending = appStoreIconRequests[appID] { return await pending.value ?? cachedImage }

        let request = Task {
            await self.fetchAppStoreIcon(appID: appID, cacheKey: cacheKey, filePath: filePath)
        }
        appStoreIconRequests[appID] = request
        let image = await request.value
        appStoreIconRequests[appID] = nil
        return image ?? cachedImage
    }

    func invalidateAppStoreIcon(appID: Int) {
        let cacheKey = "app-store-\(appID)"
        memoryCache[cacheKey] = nil
        appStoreIconDates[cacheKey] = nil
        forgetFailedLookup(cacheKey)
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        try? FileManager.default.removeItem(at: filePath)
        try? FileManager.default.removeItem(at: metricsSidecarURL(for: cacheKey))
    }

    private func cachedAppStoreIcon(cacheKey: String, filePath: URL) -> PlatformImage? {
        if let image = memoryCache[cacheKey] { return image }
        guard let data = try? Data(contentsOf: filePath), let image = PlatformImage(data: data) else { return nil }
        attachDerivedMetrics(cacheKey: cacheKey, to: image)
        memoryCache[cacheKey] = image
        return image
    }

    private func fetchAppStoreIcon(appID: Int, cacheKey: String, filePath: URL) async -> PlatformImage? {
        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(appID)&entity=software&country=us")
        else { return nil }
        var lookupRequest = URLRequest(url: lookupURL, cachePolicy: .reloadIgnoringLocalCacheData)
        lookupRequest.timeoutInterval = 10
        guard let (lookupData, lookupResponse) = try? await Self.urlSession.data(for: lookupRequest),
              let response = lookupResponse as? HTTPURLResponse, response.statusCode == 200,
              let lookup = try? JSONDecoder().decode(AppStoreIconLookup.self, from: lookupData),
              let artworkURL = lookup.results.first(where: { $0.trackId == appID })?.iconURL,
              artworkURL.scheme == "https" else {
            recordFailedLookup(cacheKey)
            return nil
        }
        let artworkRequest = URLRequest(url: artworkURL, cachePolicy: .reloadIgnoringLocalCacheData)
        guard let (imageData, imageResponse) = try? await Self.urlSession.data(for: artworkRequest),
              let response = imageResponse as? HTTPURLResponse, response.statusCode == 200,
              let image = PlatformImage(data: imageData) else {
            recordFailedLookup(cacheKey)
            return nil
        }
        forgetFailedLookup(cacheKey)
        try? FileManager.default.removeItem(at: metricsSidecarURL(for: cacheKey))
        appStoreIconDates[cacheKey] = Date()
        return cache(image, cacheKey: cacheKey, filePath: filePath)
    }
}
