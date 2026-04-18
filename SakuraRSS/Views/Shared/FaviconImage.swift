import SwiftUI
import ObjectiveC

struct FaviconImage: View {

    let image: UIImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let isCircle: Bool
    let skipInset: Bool

    var isNonSquare: Bool { !image.isSquare }
    /// Completely filled squares are treated as edge-to-edge icons and skip every automatic inset.
    var isFilledSquare: Bool { image.isFilledSquare }
    var showInset: Bool { !skipInset && isCircle && !image.isCircular && !isFilledSquare }
    var needsWhiteBackground: Bool { !skipInset && image.isDark && !isFilledSquare }
    var isNearBlack: Bool { image.isNearBlack && !isFilledSquare }

    /// In round-rect mode, a transparent favicon should be inset with a tinted background.
    var showRoundRectInset: Bool { !skipInset && !isCircle && image.isSquare && image.hasTransparentPixels }

    var iconSize: CGFloat {
        if skipInset {
            return size
        } else if isNearBlack {
            return size * 0.7
        } else if isNonSquare {
            let padding: CGFloat = isCircle ? 3 : 2
             return size - padding * 2
        } else if showInset || needsWhiteBackground || showRoundRectInset {
            return size * 0.7
        } else {
            return size
        }
    }

    var bgColor: Color {
        if skipInset {
            return .clear
        } else if isNearBlack {
            return .white
        } else if isNonSquare || needsWhiteBackground {
            return .white
        } else if showInset {
            return Color(.secondarySystemBackground)
        } else if showRoundRectInset {
            return image.nearWhiteAverageColor
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
        let shape: AnyShape = isCircle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: isNonSquare ? .fit : .fill)
            .frame(width: iconSize, height: iconSize)
            .frame(width: size, height: size)
            .background(bgColor)
            .clipShape(shape)
            .overlay(shape.stroke(.tertiary, lineWidth: 0.3))
    }
}

// MARK: - Derived Metrics (memoized)
//
// Every pixel-sampling routine below used to run on every SwiftUI body
// evaluation - i.e. once per favicon, per list row, per scroll tick.  The
// FaviconDerivedMetrics struct captures the raw results of each sampling
// pass once and is attached to the UIImage via an associated object, so
// the hot path becomes a dictionary read.  FaviconCache also persists
// the struct as a small JSON sidecar next to the cached PNG, so newly
// launched sessions can skip the sampling entirely when the favicon
// has been seen before.

nonisolated struct FaviconDerivedMetrics: Codable, Sendable {
    /// Twelve corner alpha samples (3 per corner) from a 32×32 downscaled
    /// version of the image.
    let cornerAlphas: [UInt8]
    /// Centre-pixel alpha from the same downscaled sample.
    let centerAlpha: UInt8
    /// True when the image was too small (<8px) to corner-sample reliably.
    let cornerSampleUnavailable: Bool
    /// Average RGB of every opaque pixel (16×16 sample), or `nil` when the
    /// image has no opaque pixels.
    let averageColor: [Double]?
    /// Average relative luminance (ITU-R BT.709) across opaque pixels.
    let averageLuminance: Double
    /// True when virtually every opaque pixel is near-black.
    let isNearBlack: Bool
}

private nonisolated final class FaviconDerivedMetricsBox: NSObject, @unchecked Sendable {
    let metrics: FaviconDerivedMetrics
    init(_ metrics: FaviconDerivedMetrics) { self.metrics = metrics }
}

private nonisolated(unsafe) var faviconDerivedMetricsKey: UInt8 = 0

extension UIImage {

    /// In-memory memoized metrics attached to this UIImage instance.
    nonisolated var faviconDerivedMetrics: FaviconDerivedMetrics? {
        get {
            (objc_getAssociatedObject(self, &faviconDerivedMetricsKey) as? FaviconDerivedMetricsBox)?.metrics
        }
        set {
            let box = newValue.map { FaviconDerivedMetricsBox($0) }
            objc_setAssociatedObject(
                self,
                &faviconDerivedMetricsKey,
                box,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Returns the cached metrics, computing and attaching them on first call.
    @discardableResult
    nonisolated func ensureFaviconDerivedMetrics() -> FaviconDerivedMetrics {
        if let existing = faviconDerivedMetrics { return existing }
        let cornerSample = _rawSampleCornerAlphas()
        let averageRGB = _rawAverageColorComponents()
        let luminance = _rawAverageLuminance()
        let nearBlack = _rawIsNearBlack()
        let metrics = FaviconDerivedMetrics(
            cornerAlphas: cornerSample?.corners ?? [],
            centerAlpha: cornerSample?.centerAlpha ?? 0,
            cornerSampleUnavailable: cornerSample == nil,
            averageColor: averageRGB.map { [Double($0.red), Double($0.green), Double($0.blue)] },
            averageLuminance: Double(luminance),
            isNearBlack: nearBlack
        )
        faviconDerivedMetrics = metrics
        return metrics
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
    fileprivate nonisolated func _rawSampleCornerAlphas() -> (corners: [UInt8], centerAlpha: UInt8)? {
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
        let metrics = ensureFaviconDerivedMetrics()
        guard !metrics.cornerSampleUnavailable else { return false }
        return metrics.cornerAlphas.allSatisfy { $0 <= 25 } && metrics.centerAlpha >= 200
    }

    /// Returns `true` when all corners are opaque, meaning the image completely fills
    /// the square and can be clipped to a circle at full size without needing an inset.
    var isFilledSquare: Bool {
        let metrics = ensureFaviconDerivedMetrics()
        guard !metrics.cornerSampleUnavailable else { return false }
        return metrics.cornerAlphas.allSatisfy { $0 >= 200 }
    }
}

// MARK: - Luminance Detection

extension UIImage {
    var isDark: Bool {
        ensureFaviconDerivedMetrics().averageLuminance < 0.3
    }

    /// Returns `true` when the image contains any transparent pixels.
    var hasTransparentPixels: Bool {
        !isFilledSquare
    }

    /// Computes the average colour of all opaque pixels as a SwiftUI `Color`.
    var averageColor: Color {
        guard let rgb = ensureFaviconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return .gray
        }
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    /// Raw 16×16 averaged RGB sample of opaque pixels.
    fileprivate nonisolated func _rawAverageColorComponents() -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let cgImage = cgImage else { return nil }

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
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var opaqueCount: CGFloat = 0

        for index in 0..<(sampleSize * sampleSize) {
            let offset = index * 4
            let alpha = CGFloat(pixelData[offset + 3]) / 255.0
            guard alpha > 0.1 else { continue }
            totalR += CGFloat(pixelData[offset]) / 255.0
            totalG += CGFloat(pixelData[offset + 1]) / 255.0
            totalB += CGFloat(pixelData[offset + 2]) / 255.0
            opaqueCount += 1
        }

        guard opaqueCount > 0 else { return nil }
        return (totalR / opaqueCount, totalG / opaqueCount, totalB / opaqueCount)
    }

    /// Returns an RGB tuple of the average colour of all opaque pixels.
    var averageColorComponents: (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let rgb = ensureFaviconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return nil
        }
        return (CGFloat(rgb[0]), CGFloat(rgb[1]), CGFloat(rgb[2]))
    }

    /// Returns a background colour derived from the favicon's average colour,
    /// lightened in light mode or darkened in dark mode, suitable for card backgrounds.
    func cardBackgroundColor(isDarkMode: Bool) -> Color {
        guard let avg = averageColorComponents else {
            return isDarkMode ? Color(white: 0.15) : Color(white: 0.9)
        }

        if isDarkMode {
            // Mix 65% black with 35% of the average colour for a dark tinted background
            let blend: CGFloat = 0.35
            return Color(
                red: blend * avg.red,
                green: blend * avg.green,
                blue: blend * avg.blue
            )
        } else {
            // Mix 65% white with 35% of the average colour for a light tinted background
            let whiteBlend: CGFloat = 0.65
            return Color(
                red: whiteBlend + (1 - whiteBlend) * avg.red,
                green: whiteBlend + (1 - whiteBlend) * avg.green,
                blue: whiteBlend + (1 - whiteBlend) * avg.blue
            )
        }
    }

    /// A near-white tint derived from the average colour of the image,
    /// suitable as a subtle background behind a transparent favicon.
    var nearWhiteAverageColor: Color {
        guard let rgb = ensureFaviconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return Color(.secondarySystemBackground)
        }
        let avgR = rgb[0]
        let avgG = rgb[1]
        let avgB = rgb[2]

        // Mix 85% white with 15% of the average colour
        let whiteBlend: Double = 0.85
        return Color(
            red: whiteBlend + (1 - whiteBlend) * avgR,
            green: whiteBlend + (1 - whiteBlend) * avgG,
            blue: whiteBlend + (1 - whiteBlend) * avgB
        )
    }

    /// Returns `true` when virtually all opaque pixels are near-black,
    /// meaning the icon would be invisible on a dark background.
    var isNearBlack: Bool {
        ensureFaviconDerivedMetrics().isNearBlack
    }

    fileprivate nonisolated func _rawIsNearBlack() -> Bool {
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

    fileprivate nonisolated func _rawAverageLuminance() -> CGFloat {
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
