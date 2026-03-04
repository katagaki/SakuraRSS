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

    func setCustomFavicon(_ image: UIImage, feedID: Int64) {
        let key = "custom-feed-\(feedID)"
        memoryCache[key] = image
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        if let pngData = image.pngData() {
            try? pngData.write(to: filePath)
        }
    }

    func customFavicon(feedID: Int64) -> UIImage? {
        let key = "custom-feed-\(feedID)"
        if let cached = memoryCache[key] {
            return cached
        }
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache[key] = image
            return image
        }
        return nil
    }

    func removeCustomFavicon(feedID: Int64) {
        let key = "custom-feed-\(feedID)"
        memoryCache[key] = nil
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(key))
        try? FileManager.default.removeItem(at: filePath)
    }

    private func trimAndCache(_ image: UIImage, cacheKey: String, filePath: URL) async -> UIImage {
        let trimmed = await image.trimmed()
        if let pngData = trimmed.pngData() {
            try? pngData.write(to: filePath)
        }
        memoryCache[cacheKey] = trimmed
        return trimmed
    }

    private func fetchAndCacheFavicon(
        for domain: String, siteURL: String? = nil,
        cacheKey: String, filePath: URL
    ) async -> UIImage? {
        let isYouTube = domain.contains("youtube.com") || domain.contains("youtu.be")

        if isYouTube, let siteURL = siteURL {
            if let image = await fetchYouTubeAvatar(from: siteURL) {
                return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath)
            }
        }

        guard let url = URL(string: "https://\(domain)") else { return nil }

        // Try PWA / apple-touch-icon first for higher quality
        if let image = await fetchPWAIcon(from: url) {
            return await trimAndCache(image, cacheKey: cacheKey, filePath: filePath)
        }

        // Fall back to FaviconFinder
        do {
            let faviconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestFaviconURL = faviconURLs.first else { return nil }
            let favicon = try await bestFaviconURL.download()
            guard let faviconImage = favicon.image else { return nil }
            return await trimAndCache(faviconImage.image, cacheKey: cacheKey, filePath: filePath)
        } catch {
            return nil
        }
    }

    // MARK: - PWA / Apple Touch Icon

    /// Fetches a high-quality icon from a web app manifest or apple-touch-icon.
    private nonisolated func fetchPWAIcon(from siteURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: siteURL)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // 1. Try web app manifest
            if let manifestHref = extractLinkHref(from: html, rel: "manifest"),
               let manifestURL = URL(string: manifestHref, relativeTo: siteURL) {
                if let icon = await fetchManifestIcon(from: manifestURL.absoluteURL) {
                    return icon
                }
            }

            // 2. Try apple-touch-icon (typically 180x180)
            if let touchIconHref = extractLinkHref(from: html, rel: "apple-touch-icon"),
               let iconURL = URL(string: touchIconHref, relativeTo: siteURL) {
                let (iconData, _) = try await URLSession.shared.data(from: iconURL.absoluteURL)
                if let image = UIImage(data: iconData), image.size.width >= 64 {
                    return image
                }
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Fetches the largest icon from a web app manifest JSON.
    private nonisolated func fetchManifestIcon(from manifestURL: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: manifestURL)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let icons = json["icons"] as? [[String: Any]] else { return nil }

            // Find the largest square icon
            var bestIcon: (url: String, size: Int)?
            for icon in icons {
                guard let src = icon["src"] as? String else { continue }
                let size = parseIconSize(icon["sizes"] as? String)
                if size > (bestIcon?.size ?? 0) {
                    bestIcon = (src, size)
                }
            }

            guard let iconSrc = bestIcon?.url,
                  let iconURL = URL(string: iconSrc, relativeTo: manifestURL) else { return nil }

            let (iconData, _) = try await URLSession.shared.data(from: iconURL.absoluteURL)
            if let image = UIImage(data: iconData), image.size.width >= 64 {
                return image
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Parses icon size strings like "192x192" and returns the width.
    private nonisolated func parseIconSize(_ sizes: String?) -> Int {
        guard let sizes = sizes else { return 0 }
        let parts = sizes.lowercased().split(separator: "x")
        return Int(parts.first ?? "") ?? 0
    }

    // MARK: - YouTube

    /// Fetches the YouTube channel avatar by scraping the channel page for the og:image meta tag.
    private nonisolated func fetchYouTubeAvatar(from siteURL: String) async -> UIImage? {
        guard let url = URL(string: siteURL) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            guard let imageURL = extractMetaContent(from: html, property: "og:image"),
                  let avatarURL = URL(string: imageURL) else { return nil }

            let (imageData, _) = try await URLSession.shared.data(from: avatarURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    // MARK: - HTML Parsing Helpers

    /// Extracts the href attribute from a link tag with the given rel value.
    private nonisolated func extractLinkHref(from html: String, rel: String) -> String? {
        let patterns = [
            "<link[^>]+rel=\"\(rel)\"[^>]+href=\"([^\"]+)\"",
            "<link[^>]+href=\"([^\"]+)\"[^>]+rel=\"\(rel)\""
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

    /// Extracts the content attribute from a meta tag with the given property.
    private nonisolated func extractMetaContent(from html: String, property: String) -> String? {
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

    // swiftlint:disable cyclomatic_complexity for_where function_body_length
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
            let alpha = CGFloat(pixelData[offset + 3]) / 255.0
            if alpha < 0.1 { return true }
            let red = CGFloat(pixelData[offset]) / 255.0 / alpha
            let green = CGFloat(pixelData[offset + 1]) / 255.0 / alpha
            let blue = CGFloat(pixelData[offset + 2]) / 255.0 / alpha
            return red >= tolerance && green >= tolerance && blue >= tolerance
        }

        var top = 0
        var bottom = height - 1
        var left = 0
        var right = width - 1

        topScan: for yValue in 0..<height {
            for xValue in 0..<width {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break topScan }
            }
            top = yValue + 1
        }

        bottomScan: for yValue in stride(from: height - 1, through: top, by: -1) {
            for xValue in 0..<width {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break bottomScan }
            }
            bottom = yValue - 1
        }

        guard top <= bottom else { return nil }

        leftScan: for xValue in 0..<width {
            for yValue in top...bottom {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break leftScan }
            }
            left = xValue + 1
        }

        rightScan: for xValue in stride(from: width - 1, through: left, by: -1) {
            for yValue in top...bottom {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break rightScan }
            }
            right = xValue - 1
        }

        guard left <= right else { return nil }

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
    // swiftlint:enable cyclomatic_complexity for_where function_body_length
}

extension UIImage {

    /// Returns a copy with transparent/near-white padding cropped, or self if no significant padding.
    @MainActor func trimmed() -> UIImage {
        guard let cgImage,
              let cropped = BlankPaddingTrimmer.trim(cgImage) else {
            return self
        }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
