import Foundation
import ImageIO
import UniformTypeIdentifiers

public nonisolated extension ImageDownsampler {

    static let cacheMaxPixelSize: CGFloat = 2000
    private static let reencodeByteThreshold = 512 * 1024
    private static let reencodeQuality: CGFloat = 0.8

    /// Shrinks oversized sources before they are written to the image cache so
    /// every later cache hit decodes a display-sized image instead of the original.
    /// Animated images and re-encodes that would come out larger keep their bytes.
    static func cacheableData(_ data: Data, maxPixelSize: CGFloat = cacheMaxPixelSize) -> Data {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue else {
            return data
        }
        let longestSide = CGFloat(max(pixelWidth, pixelHeight))
        guard longestSide > maxPixelSize || data.count > reencodeByteThreshold else { return data }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: min(longestSide, maxPixelSize)
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary
        ) else { return data }

        let hasAlpha = (properties[kCGImagePropertyHasAlpha] as? Bool) ?? false
        let encodedType = hasAlpha ? UTType.heic : UTType.jpeg
        guard let encoded = encode(thumbnail, as: encodedType), encoded.count < data.count else {
            return data
        }
        return encoded
    }

    private static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, type.identifier as CFString, 1, nil
        ) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: reencodeQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
