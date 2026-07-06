import Foundation
import ImageIO
import UIKit

/// ImageIO-backed thumbnail helpers that avoid full-resolution decoding.
public nonisolated enum ImageDownsampler {

    /// Downsamples encoded bytes to a thumbnail whose largest dimension is `maxPixelSize`.
    /// Pass `cacheImmediately: false` in memory-constrained processes (widgets) so the
    /// decoded bitmap is not pinned by the image source.
    public nonisolated static func downsample(
        _ data: Data,
        maxPixelSize: CGFloat,
        cacheImmediately: Bool = true
    ) -> UIImage? {
        guard let source = createSource(from: data) else { return nil }
        return downsample(source: source, maxPixelSize: maxPixelSize, cacheImmediately: cacheImmediately)
    }

    /// Downsamples encoded bytes and returns JPEG-encoded thumbnail bytes.
    public nonisolated static func downsampleToJPEG(
        _ data: Data,
        maxPixelSize: CGFloat,
        quality: CGFloat = 0.7,
        cacheImmediately: Bool = true
    ) -> Data? {
        guard let image = downsample(
            data, maxPixelSize: maxPixelSize, cacheImmediately: cacheImmediately
        ) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }

    nonisolated private static func createSource(from data: Data) -> CGImageSource? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        return CGImageSourceCreateWithData(data as CFData, options as CFDictionary)
    }

    nonisolated private static func downsample(
        source: CGImageSource,
        maxPixelSize: CGFloat,
        cacheImmediately: Bool
    ) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: cacheImmediately,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
