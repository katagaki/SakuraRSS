import Foundation
import UIKit
import FaviconFinder

actor FaviconCache {

    static let shared = FaviconCache()

    private let cacheDirectory: URL
    private var memoryCache: [String: UIImage] = [:]

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        cacheDirectory = containerURL.appendingPathComponent("FaviconCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func favicon(for domain: String) async -> UIImage? {
        if let cached = memoryCache[domain] {
            return cached
        }

        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(domain))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache[domain] = image
            return image
        }

        do {
            guard let url = URL(string: "https://\(domain)") else { return nil }
            let faviconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestFaviconURL = faviconURLs.first else { return nil }
            let favicon = try await bestFaviconURL.download()
            guard let faviconImage = favicon.image else { return nil }
            let uiImage = faviconImage.image

            if let pngData = uiImage.pngData() {
                try? pngData.write(to: filePath)
            }
            memoryCache[domain] = uiImage
            return uiImage
        } catch {
            return nil
        }
    }

    func clearCache() {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func sanitizedFileName(_ domain: String) -> String {
        domain.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_") + ".png"
    }
}
