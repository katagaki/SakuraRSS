import SwiftUI
import ObjectiveC

struct IconImage: View {

    let image: UIImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let isCircle: Bool
    let skipInset: Bool

    var isNonSquare: Bool { !image.isSquare }
    var isFilledSquare: Bool { image.isFilledSquare }
    var showInset: Bool { !skipInset && isCircle && !image.isCircular && image.hasTransparentPixels }
    var needsWhiteBackground: Bool { !skipInset && image.isDark && image.hasTransparentPixels }
    var isNearBlack: Bool { image.isNearBlack && image.hasTransparentPixels }
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

    init(_ image: UIImage, size: CGFloat = 20, cornerRadius: CGFloat = 3,
         circle: Bool = false, skipInset: Bool = false) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius
        self.isCircle = circle
        self.skipInset = skipInset
    }

    var body: some View {
        let baseImage = Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: isNonSquare ? .fit : .fill)
            .frame(width: iconSize, height: iconSize)
            .frame(width: size, height: size)
            .background(image.nearWhiteAverageGradient)

        if isCircle {
            baseImage
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                }
        } else {
            baseImage
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Derived Metrics (memoized)

nonisolated struct IconDerivedMetrics: Codable, Sendable {
    let cornerAlphas: [UInt8]
    let centerAlpha: UInt8
    let cornerSampleUnavailable: Bool
    let averageColor: [Double]?
    let averageLuminance: Double
    let isNearBlack: Bool
    let prominentColors: [[Double]]?
    let hasAnyTransparentPixel: Bool?
}

private nonisolated final class IconDerivedMetricsBox: NSObject, @unchecked Sendable {
    let metrics: IconDerivedMetrics
    init(_ metrics: IconDerivedMetrics) { self.metrics = metrics }
}

private nonisolated(unsafe) var iconDerivedMetricsKey: UInt8 = 0

extension UIImage {

    nonisolated var iconDerivedMetrics: IconDerivedMetrics? {
        get {
            (objc_getAssociatedObject(self, &iconDerivedMetricsKey) as? IconDerivedMetricsBox)?.metrics
        }
        set {
            let box = newValue.map { IconDerivedMetricsBox($0) }
            objc_setAssociatedObject(
                self,
                &iconDerivedMetricsKey,
                box,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    @discardableResult
    nonisolated func ensureIconDerivedMetrics() -> IconDerivedMetrics {
        if let existing = iconDerivedMetrics,
           existing.prominentColors != nil,
           existing.hasAnyTransparentPixel != nil {
            return existing
        }
        let cornerSample = rawSampleCornerAlphas()
        let averageRGB = rawAverageColorComponents()
        let luminance = rawAverageLuminance()
        let nearBlack = rawIsNearBlack()
        let prominent = rawProminentColors()
        let anyTransparent = rawHasAnyTransparentPixel()
        let metrics = IconDerivedMetrics(
            cornerAlphas: cornerSample?.corners ?? [],
            centerAlpha: cornerSample?.centerAlpha ?? 0,
            cornerSampleUnavailable: cornerSample == nil,
            averageColor: averageRGB.map { [Double($0.red), Double($0.green), Double($0.blue)] },
            averageLuminance: Double(luminance),
            isNearBlack: nearBlack,
            prominentColors: prominent,
            hasAnyTransparentPixel: anyTransparent
        )
        iconDerivedMetrics = metrics
        return metrics
    }
}

// MARK: - Shape Detection

extension UIImage {

    var isSquare: Bool {
        guard let cgImage = cgImage else { return true }
        return cgImage.width == cgImage.height
    }

    fileprivate nonisolated func rawSampleCornerAlphas() -> (corners: [UInt8], centerAlpha: UInt8)? {
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

    /// True when corners are transparent and centre is opaque (already circular/rounded).
    var isCircular: Bool {
        let metrics = ensureIconDerivedMetrics()
        guard !metrics.cornerSampleUnavailable else { return false }
        return metrics.cornerAlphas.allSatisfy { $0 <= 25 } && metrics.centerAlpha >= 200
    }

    /// True when all corners are opaque; the image fills the square edge-to-edge.
    var isFilledSquare: Bool {
        let metrics = ensureIconDerivedMetrics()
        guard !metrics.cornerSampleUnavailable else { return false }
        return metrics.cornerAlphas.allSatisfy { $0 >= 200 }
    }
}

// MARK: - Luminance Detection

extension UIImage {
    var isDark: Bool {
        ensureIconDerivedMetrics().averageLuminance < 0.3
    }

    var hasTransparentPixels: Bool {
        ensureIconDerivedMetrics().hasAnyTransparentPixel ?? !isFilledSquare
    }

    var averageColor: Color {
        guard let rgb = ensureIconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return .gray
        }
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    fileprivate nonisolated func rawAverageColorComponents() -> RGBComponents? {
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
        return RGBComponents(
            red: totalR / opaqueCount,
            green: totalG / opaqueCount,
            blue: totalB / opaqueCount
        )
    }

    var averageColorComponents: RGBComponents? {
        guard let rgb = ensureIconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return nil
        }
        return RGBComponents(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]))
    }

    /// Background colour derived from the icon's average colour for card backgrounds.
    func cardBackgroundColor(isDarkMode: Bool) -> Color {
        guard let avg = averageColorComponents else {
            return isDarkMode ? Color(white: 0.15) : Color(white: 0.9)
        }

        if isDarkMode {
            let blend: CGFloat = 0.35
            return Color(
                red: blend * avg.red,
                green: blend * avg.green,
                blue: blend * avg.blue
            )
        } else {
            let whiteBlend: CGFloat = 0.65
            return Color(
                red: whiteBlend + (1 - whiteBlend) * avg.red,
                green: whiteBlend + (1 - whiteBlend) * avg.green,
                blue: whiteBlend + (1 - whiteBlend) * avg.blue
            )
        }
    }

    /// Near-white gradient derived from the average colour for backgrounds behind transparent icons.
    var nearWhiteAverageGradient: LinearGradient {
        guard let rgb = ensureIconDerivedMetrics().averageColor, rgb.count >= 3 else {
            return LinearGradient(
                colors: [Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        let mean = (rgb[0] + rgb[1] + rgb[2]) / 3.0
        let saturationBoost: Double = 1.5
        let boostedR = max(0, min(1, mean + (rgb[0] - mean) * saturationBoost))
        let boostedG = max(0, min(1, mean + (rgb[1] - mean) * saturationBoost))
        let boostedB = max(0, min(1, mean + (rgb[2] - mean) * saturationBoost))

        let topBlend: Double = 0.7
        let bottomBlend: Double = 0.55
        let top = Color(
            red: topBlend + (1 - topBlend) * boostedR,
            green: topBlend + (1 - topBlend) * boostedG,
            blue: topBlend + (1 - topBlend) * boostedB
        )
        let bottom = Color(
            red: bottomBlend + (1 - bottomBlend) * boostedR,
            green: bottomBlend + (1 - bottomBlend) * boostedG,
            blue: bottomBlend + (1 - bottomBlend) * boostedB
        )
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// True when virtually all opaque pixels are near-black.
    var isNearBlack: Bool {
        ensureIconDerivedMetrics().isNearBlack
    }

}
