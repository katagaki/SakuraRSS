import Foundation
import ImageIO
import UIKit

/// ImageIO-backed thumbnail helpers that avoid full-resolution decoding.
nonisolated enum ImageDownsampler {

    /// Downsamples encoded bytes to a thumbnail whose largest dimension is `maxPixelSize`.
    nonisolated static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = createSource(from: data) else { return nil }
        return downsample(source: source, maxPixelSize: maxPixelSize)
    }

    /// Downsamples encoded bytes and returns JPEG-encoded thumbnail bytes.
    nonisolated static func downsampleToJPEG(
        _ data: Data,
        maxPixelSize: CGFloat,
        quality: CGFloat = 0.7
    ) -> Data? {
        guard let image = downsample(data, maxPixelSize: maxPixelSize) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }

    nonisolated private static func createSource(from data: Data) -> CGImageSource? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        return CGImageSourceCreateWithData(data as CFData, options as CFDictionary)
    }

    nonisolated private static func downsample(source: CGImageSource, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
