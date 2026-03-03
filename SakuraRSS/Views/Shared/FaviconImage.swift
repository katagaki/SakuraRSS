import SwiftUI

struct FaviconImage: View {

    let image: UIImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let isCircle: Bool
    let skipInset: Bool

    var isNonSquare: Bool { !image.isSquare }
    var showInset: Bool { !skipInset && isCircle && !image.isCircular && !image.isFilledSquare }
    var needsWhiteBackground: Bool { !skipInset && image.isDark }
    var isNearBlack: Bool { image.isNearBlack }

    var iconSize: CGFloat {
        if isNearBlack {
            return size * 0.7
        } else if skipInset {
            return size
        } else if isNonSquare {
            let padding: CGFloat = isCircle ? 3 : 2
             return size - padding * 2
        } else if showInset || needsWhiteBackground {
            return size * 0.7
        } else {
            return size
        }
    }

    var bgColor: Color {
        if isNearBlack {
            return .white
        } else if skipInset {
            return .clear
        } else if isNonSquare || needsWhiteBackground {
            return .white
        } else if showInset {
            return Color(.secondarySystemBackground)
        } else {
            return .clear
        }
    }

    init(_ image: UIImage, size: CGFloat = 20, cornerRadius: CGFloat = 3,
         circle: Bool = false, skipInset: Bool = false) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius
        self.isCircle = circle
        self.skipInset = skipInset
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: isNonSquare ? .fit : .fill)
            .frame(width: iconSize, height: iconSize)
            .frame(width: size, height: size)
            .background(bgColor)
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }
}

// MARK: - Shape Detection

extension UIImage {

    /// Returns `true` when the image has equal width and height.
    var isSquare: Bool {
        guard let cgImage = cgImage else { return true }
        return cgImage.width == cgImage.height
    }

    /// Samples corner and center pixel alpha values from a downscaled version of the image.
    private func sampleCornerAlphas() -> (corners: [UInt8], centerAlpha: UInt8)? {
        guard let cgImage = cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width >= 8, height >= 8 else { return nil }

        let sampleSize = min(min(width, height), 32)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = sampleSize * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        let last = sampleSize - 1
        let cornerPoints = [
            (0, 0), (1, 0), (0, 1),
            (last, 0), (last - 1, 0), (last, 1),
            (0, last), (1, last), (0, last - 1),
            (last, last), (last - 1, last), (last, last - 1)
        ]

        let corners = cornerPoints.map { (xCoord, yCoord) in
            pixelData[(yCoord * sampleSize + xCoord) * bytesPerPixel + 3]
        }
        let mid = sampleSize / 2
        let centerAlpha = pixelData[(mid * sampleSize + mid) * bytesPerPixel + 3]
        return (corners, centerAlpha)
    }

    /// Returns `true` when the image corners are transparent and the centre is opaque,
    /// indicating the favicon is already circular (or rounded) and needs no inset treatment.
    var isCircular: Bool {
        guard let sample = sampleCornerAlphas() else { return false }
        return sample.corners.allSatisfy { $0 <= 25 } && sample.centerAlpha >= 200
    }

    /// Returns `true` when all corners are opaque, meaning the image completely fills
    /// the square and can be clipped to a circle at full size without needing an inset.
    var isFilledSquare: Bool {
        guard let sample = sampleCornerAlphas() else { return false }
        return sample.corners.allSatisfy { $0 >= 200 }
    }
}

// MARK: - Luminance Detection

extension UIImage {
    var isDark: Bool {
        averageLuminance < 0.3
    }

    /// Returns `true` when virtually all opaque pixels are near-black,
    /// meaning the icon would be invisible on a dark background.
    var isNearBlack: Bool {
        guard let cgImage = cgImage else { return false }

        let sampleSize = 16
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var opaqueCount = 0
        var nearBlackCount = 0
        let pixelCount = sampleSize * sampleSize

        for index in 0..<pixelCount {
            let offset = index * 4
            let alpha = pixelData[offset + 3]
            guard alpha > 25 else { continue }
            opaqueCount += 1
            let maxChannel = max(pixelData[offset], max(pixelData[offset + 1], pixelData[offset + 2]))
            if maxChannel < 30 {
                nearBlackCount += 1
            }
        }

        guard opaqueCount > 0 else { return false }
        return Double(nearBlackCount) / Double(opaqueCount) > 0.9
    }

    private var averageLuminance: CGFloat {
        guard let cgImage = cgImage else { return 1.0 }

        let sampleSize = 16
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 1.0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var totalLuminance: CGFloat = 0
        var opaquePixelCount: CGFloat = 0
        let pixelCount = sampleSize * sampleSize

        for index in 0..<pixelCount {
            let offset = index * 4
            let alpha = CGFloat(pixelData[offset + 3]) / 255.0
            guard alpha > 0.1 else { continue }

            let red = CGFloat(pixelData[offset]) / 255.0
            let green = CGFloat(pixelData[offset + 1]) / 255.0
            let blue = CGFloat(pixelData[offset + 2]) / 255.0

            // Relative luminance (ITU-R BT.709)
            totalLuminance += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            opaquePixelCount += 1
        }

        guard opaquePixelCount > 0 else { return 1.0 }
        return totalLuminance / opaquePixelCount
    }
}
