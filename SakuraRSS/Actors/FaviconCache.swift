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

    func favicon(for domain: String, siteURL: String? = nil) async -> UIImage? {
        let cacheKey = Self.cacheKey(domain: domain, siteURL: siteURL)

        if let cached = memoryCache[cacheKey] {
            return cached
        }

        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            let trimmed = await image.trimmed()
            memoryCache[cacheKey] = trimmed
            return trimmed
        }

        return await fetchAndCacheFavicon(for: domain, siteURL: siteURL, cacheKey: cacheKey, filePath: filePath)
    }

    /// Clears caches for the given domains and re-fetches their favicons.
    func refreshFavicons(for entries: [(domain: String, siteURL: String?)]) async {
        for entry in entries {
            let cacheKey = Self.cacheKey(domain: entry.domain, siteURL: entry.siteURL)
            memoryCache[cacheKey] = nil
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
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func fetchAndCacheFavicon(
        for domain: String, siteURL: String? = nil,
        cacheKey: String, filePath: URL
    ) async -> UIImage? {
        let isYouTube = domain.contains("youtube.com") || domain.contains("youtu.be")

        if isYouTube, let siteURL = siteURL {
            if let image = await fetchYouTubeAvatar(from: siteURL) {
                let trimmed = await image.trimmed()
                if let pngData = trimmed.pngData() {
                    try? pngData.write(to: filePath)
                }
                memoryCache[cacheKey] = trimmed
                return trimmed
            }
        }

        do {
            guard let url = URL(string: "https://\(domain)") else { return nil }
            let faviconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestFaviconURL = faviconURLs.first else { return nil }
            let favicon = try await bestFaviconURL.download()
            guard let faviconImage = favicon.image else { return nil }
            let uiImage = faviconImage.image
            let trimmed = await uiImage.trimmed()

            if let pngData = trimmed.pngData() {
                try? pngData.write(to: filePath)
            }
            memoryCache[cacheKey] = trimmed
            return trimmed
        } catch {
            return nil
        }
    }

    /// Fetches the YouTube channel avatar by scraping the channel page for the og:image meta tag.
    private nonisolated func fetchYouTubeAvatar(from siteURL: String) async -> UIImage? {
        guard let url = URL(string: siteURL) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // Look for <meta property="og:image" content="...">
            guard let imageURL = extractMetaContent(from: html, property: "og:image"),
                  let avatarURL = URL(string: imageURL) else { return nil }

            let (imageData, _) = try await URLSession.shared.data(from: avatarURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    /// Extracts the content attribute from a meta tag with the given property.
    private nonisolated func extractMetaContent(from html: String, property: String) -> String? {
        // Match <meta property="og:image" content="..."> or <meta content="..." property="og:image">
        let patterns = [
            "<meta[^>]+property=\"\(property)\"[^>]+content=\"([^\"]+)\"",
            "<meta[^>]+content=\"([^\"]+)\"[^>]+property=\"\(property)\""
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    private nonisolated static func cacheKey(domain: String, siteURL: String?) -> String {
        let isYouTube = domain.contains("youtube.com") || domain.contains("youtu.be")
        guard isYouTube, let siteURL = siteURL, let url = URL(string: siteURL) else {
            return domain
        }
        let host = url.host ?? domain
        let path = url.path
        return path.isEmpty ? host : host + path
    }

    private func sanitizedFileName(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_") + ".png"
    }
}

// MARK: - Blank Padding Trimming

private enum BlankPaddingTrimmer {

    /// Crops transparent or near-white padding from a CGImage.
    static func trim(_ cgImage: CGImage, tolerance: CGFloat = 0.95) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isBlank(at offset: Int) -> Bool {
            let a = CGFloat(pixelData[offset + 3]) / 255.0
            if a < 0.1 { return true }
            let r = CGFloat(pixelData[offset]) / 255.0 / a
            let g = CGFloat(pixelData[offset + 1]) / 255.0 / a
            let b = CGFloat(pixelData[offset + 2]) / 255.0 / a
            return r >= tolerance && g >= tolerance && b >= tolerance
        }

        var top = 0
        var bottom = height - 1
        var left = 0
        var right = width - 1

        topScan: for y in 0..<height {
            for x in 0..<width {
                if !isBlank(at: (y * width + x) * bytesPerPixel) { break topScan }
            }
            top = y + 1
        }

        bottomScan: for y in stride(from: height - 1, through: top, by: -1) {
            for x in 0..<width {
                if !isBlank(at: (y * width + x) * bytesPerPixel) { break bottomScan }
            }
            bottom = y - 1
        }

        leftScan: for x in 0..<width {
            for y in top...bottom {
                if !isBlank(at: (y * width + x) * bytesPerPixel) { break leftScan }
            }
            left = x + 1
        }

        rightScan: for x in stride(from: width - 1, through: left, by: -1) {
            for y in top...bottom {
                if !isBlank(at: (y * width + x) * bytesPerPixel) { break rightScan }
            }
            right = x - 1
        }

        let cropWidth = right - left + 1
        let cropHeight = bottom - top + 1

        let minTrim = max(1, min(width, height) / 10)
        guard top >= minTrim || (height - 1 - bottom) >= minTrim ||
              left >= minTrim || (width - 1 - right) >= minTrim else {
            return nil
        }

        guard cropWidth > 0, cropHeight > 0 else { return nil }

        let cropRect = CGRect(x: left, y: top, width: cropWidth, height: cropHeight)
        return cgImage.cropping(to: cropRect)
    }
}

extension UIImage {

    /// Returns a copy with transparent/near-white padding cropped, or self if no significant padding.
    @MainActor func trimmed() -> UIImage {
        guard let cg = cgImage,
              let cropped = BlankPaddingTrimmer.trim(cg) else {
            return self
        }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
