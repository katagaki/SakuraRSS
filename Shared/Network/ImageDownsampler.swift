import Foundation
import ImageIO
import UIKit

/// ImageIO-backed thumbnail helpers.  Preferred over
/// `UIImage(data:) → byPreparingThumbnail(ofSize:)` because
/// `CGImageSource` decodes only enough of the source to produce the
/// thumbnail — a full-resolution photo never has to land in memory
/// as a UIImage, which matters in the widget extension's tight
/// memory budget and for main-app scroll smoothness.
///
/// Marked `nonisolated` because the app target infers `@MainActor`
/// isolation for UIKit-using types by default; every method here is
/// pure and safe to call from any actor / thread.
nonisolated enum ImageDownsampler {

    /// Downsamples the encoded bytes in `data` to a thumbnail whose
    /// largest dimension is `maxPixelSize`, returning a decoded
    /// `UIImage`.  Returns `nil` if the source cannot be decoded.
    nonisolated static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = createSource(from: data) else { return nil }
        return downsample(source: source, maxPixelSize: maxPixelSize)
    }

    /// Downsamples the encoded bytes in `data` to a thumbnail whose
    /// largest dimension is `maxPixelSize` and returns JPEG-encoded
    /// bytes suitable for storing/transporting (e.g. widget entry
    /// payloads).  Returns `nil` on any failure.
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
        guard let cg = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: cg)
    }
}
