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
            let trimmed = trimBlankPadding(from: image) ?? image
            memoryCache[domain] = trimmed
            return trimmed
        }

        return await fetchAndCacheFavicon(for: domain, filePath: filePath)
    }

    /// Clears caches for the given domains and re-fetches their favicons.
    func refreshFavicons(for domains: [String]) async {
        for domain in domains {
            memoryCache[domain] = nil
            let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(domain))
            try? FileManager.default.removeItem(at: filePath)
        }
        await withTaskGroup(of: Void.self) { group in
            for domain in domains {
                let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(domain))
                group.addTask {
                    _ = await self.fetchAndCacheFavicon(for: domain, filePath: filePath)
                }
            }
        }
    }

    func clearCache() {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func fetchAndCacheFavicon(for domain: String, filePath: URL) async -> UIImage? {
        do {
            guard let url = URL(string: "https://\(domain)") else { return nil }
            let faviconURLs = try await FaviconFinder(url: url).fetchFaviconURLs()
            guard let bestFaviconURL = faviconURLs.first else { return nil }
            let favicon = try await bestFaviconURL.download()
            guard let faviconImage = favicon.image else { return nil }
            let uiImage = faviconImage.image
            let trimmed = trimBlankPadding(from: uiImage) ?? uiImage

            if let pngData = trimmed.pngData() {
                try? pngData.write(to: filePath)
            }
            memoryCache[domain] = trimmed
            return trimmed
        } catch {
            return nil
        }
    }

    private func sanitizedFileName(_ domain: String) -> String {
        domain.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_") + ".png"
    }
}

// MARK: - Blank Padding Trimming

/// Crops transparent or near-white padding around the icon content.
/// Uses CGImage directly to avoid main-actor isolation requirements of UIImage.
private func trimBlankPadding(from image: UIImage, tolerance: CGFloat = 0.95) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }

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

    // Scan from top
    topScan: for y in 0..<height {
        for x in 0..<width {
            if !isBlank(at: (y * width + x) * bytesPerPixel) { break topScan }
        }
        top = y + 1
    }

    // Scan from bottom
    bottomScan: for y in stride(from: height - 1, through: top, by: -1) {
        for x in 0..<width {
            if !isBlank(at: (y * width + x) * bytesPerPixel) { break bottomScan }
        }
        bottom = y - 1
    }

    // Scan from left
    leftScan: for x in 0..<width {
        for y in top...bottom {
            if !isBlank(at: (y * width + x) * bytesPerPixel) { break leftScan }
        }
        left = x + 1
    }

    // Scan from right
    rightScan: for x in stride(from: width - 1, through: left, by: -1) {
        for y in top...bottom {
            if !isBlank(at: (y * width + x) * bytesPerPixel) { break rightScan }
        }
        right = x - 1
    }

    let cropWidth = right - left + 1
    let cropHeight = bottom - top + 1

    // Only trim if we'd remove at least 10% from any side
    let minTrim = max(1, min(width, height) / 10)
    guard top >= minTrim || (height - 1 - bottom) >= minTrim ||
          left >= minTrim || (width - 1 - right) >= minTrim else {
        return nil
    }

    guard cropWidth > 0, cropHeight > 0 else { return nil }

    let cropRect = CGRect(x: left, y: top, width: cropWidth, height: cropHeight)
    guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
}
