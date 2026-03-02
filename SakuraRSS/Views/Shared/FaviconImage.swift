import SwiftUI

struct FaviconImage: View {

    let image: UIImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let isCircle: Bool
    let skipInset: Bool

    init(_ image: UIImage, size: CGFloat = 20, cornerRadius: CGFloat = 3,
         circle: Bool = false, skipInset: Bool = false) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius
        self.isCircle = circle
        self.skipInset = skipInset
    }

    var body: some View {
        let showInset = !skipInset && isCircle && !image.isCircular && !image.isFilledSquare
        let needsWhiteBackground = !skipInset && image.isDark
        let iconScale: CGFloat = showInset || needsWhiteBackground ? 0.7 : 1.0

        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size * iconScale, height: size * iconScale)
            .frame(width: size, height: size)
            .background(needsWhiteBackground ? .white : (showInset ? Color(.secondarySystemBackground) : .clear))
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }
}

// MARK: - Shape Detection

extension UIImage {

    /// Returns `true` when the image corners are transparent and the centre is opaque,
    /// indicating the favicon is already circular (or rounded) and needs no inset treatment.
    var isCircular: Bool {
        guard let cgImage = cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        guard width >= 8, height >= 8 else { return false }

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
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        func alpha(x: Int, y: Int) -> UInt8 {
            pixelData[(y * sampleSize + x) * bytesPerPixel + 3]
        }

        let last = sampleSize - 1
        let cornerSamples = [
            (0, 0), (1, 0), (0, 1),
            (last, 0), (last - 1, 0), (last, 1),
            (0, last), (1, last), (0, last - 1),
            (last, last), (last - 1, last), (last, last - 1)
        ]

        for (x, y) in cornerSamples {
            if alpha(x: x, y: y) > 25 { return false }
        }

        let mid = sampleSize / 2
        return alpha(x: mid, y: mid) >= 200
    }

    /// Returns `true` when all corners are opaque, meaning the image completely fills
    /// the square and can be clipped to a circle at full size without needing an inset.
    var isFilledSquare: Bool {
        guard let cgImage = cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        guard width >= 8, height >= 8 else { return false }

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
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        func alpha(x: Int, y: Int) -> UInt8 {
            pixelData[(y * sampleSize + x) * bytesPerPixel + 3]
        }

        let last = sampleSize - 1
        let cornerSamples = [
            (0, 0), (1, 0), (0, 1),
            (last, 0), (last - 1, 0), (last, 1),
            (0, last), (1, last), (0, last - 1),
            (last, last), (last - 1, last), (last, last - 1)
        ]

        for (x, y) in cornerSamples {
            if alpha(x: x, y: y) < 200 { return false }
        }

        return true
    }
}

// MARK: - Luminance Detection

extension UIImage {
    var isDark: Bool {
        averageLuminance < 0.3
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

        for i in 0..<pixelCount {
            let offset = i * 4
            let alpha = CGFloat(pixelData[offset + 3]) / 255.0
            guard alpha > 0.1 else { continue }

            let r = CGFloat(pixelData[offset]) / 255.0
            let g = CGFloat(pixelData[offset + 1]) / 255.0
            let b = CGFloat(pixelData[offset + 2]) / 255.0

            // Relative luminance (ITU-R BT.709)
            totalLuminance += 0.2126 * r + 0.7152 * g + 0.0722 * b
            opaquePixelCount += 1
        }

        guard opaquePixelCount > 0 else { return 1.0 }
        return totalLuminance / opaquePixelCount
    }
}
