import AppKit
import Hanami

/// Reads an image from the database's image cache, as iOS does, before going to the network.
enum CachedImageData {

    // NSCache is thread-safe.
    nonisolated(unsafe) private static let decodedImages: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 150 * 1024 * 1024
        return cache
    }()

    @concurrent nonisolated static func load(_ url: URL) async -> Data? {
        if let cached = try? DatabaseManager.shared.cachedImageData(for: url.absoluteString) {
            return cached
        }
        return try? await URLSession.shared.data(for: .sakuraImage(url: url)).0
    }

    nonisolated static func cachedImage(_ url: URL, maxPixelSize: CGFloat) -> NSImage? {
        decodedImages.object(forKey: cacheKey(url, maxPixelSize))
    }

    /// Decodes off the main thread at no more than `maxPixelSize`; `NSImage(data:)`
    /// defers decoding to the first draw, which stalls scrolling on large images.
    @concurrent nonisolated static func image(_ url: URL, maxPixelSize: CGFloat) async -> NSImage? {
        if let cached = cachedImage(url, maxPixelSize: maxPixelSize) {
            return cached
        }
        guard let data = await load(url),
              let image = ImageDownsampler.downsample(data, maxPixelSize: maxPixelSize) else {
            return nil
        }
        let cost = Int(image.size.width * image.size.height * 4)
        decodedImages.setObject(image, forKey: cacheKey(url, maxPixelSize), cost: cost)
        return image
    }

    nonisolated private static func cacheKey(_ url: URL, _ maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)|\(Int(maxPixelSize))" as NSString
    }
}
