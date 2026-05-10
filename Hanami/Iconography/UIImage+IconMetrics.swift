import UIKit
import ObjectiveC

public nonisolated struct IconDerivedMetrics: Codable, Sendable {
    public let cornerAlphas: [UInt8]
    public let centerAlpha: UInt8
    public let cornerSampleUnavailable: Bool
    public let averageColor: [Double]?
    public let averageLuminance: Double
    public let isNearBlack: Bool
    public let prominentColors: [[Double]]?
    public let hasAnyTransparentPixel: Bool?

    public init(
        cornerAlphas: [UInt8],
        centerAlpha: UInt8,
        cornerSampleUnavailable: Bool,
        averageColor: [Double]?,
        averageLuminance: Double,
        isNearBlack: Bool,
        prominentColors: [[Double]]?,
        hasAnyTransparentPixel: Bool?
    ) {
        self.cornerAlphas = cornerAlphas
        self.centerAlpha = centerAlpha
        self.cornerSampleUnavailable = cornerSampleUnavailable
        self.averageColor = averageColor
        self.averageLuminance = averageLuminance
        self.isNearBlack = isNearBlack
        self.prominentColors = prominentColors
        self.hasAnyTransparentPixel = hasAnyTransparentPixel
    }
}

private nonisolated final class IconDerivedMetricsBox: NSObject, @unchecked Sendable {
    let metrics: IconDerivedMetrics
    init(_ metrics: IconDerivedMetrics) { self.metrics = metrics }
}

private nonisolated(unsafe) var iconDerivedMetricsKey: UInt8 = 0

public extension UIImage {

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

public extension UIImage {

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

    var isCircular: Bool {
        let metrics = ensureIconDerivedMetrics()
        guard !metrics.cornerSampleUnavailable else { return false }
        return metrics.cornerAlphas.allSatisfy { $0 <= 25 } && metrics.centerAlpha >= 200
    }

    var isFilledSquare: Bool {
        let metrics = ensureIconDerivedMetrics()
        guard !metrics.cornerSampleUnavailable else { return false }
        return metrics.cornerAlphas.allSatisfy { $0 >= 200 }
    }
}

public extension UIImage {

    var isDark: Bool {
        ensureIconDerivedMetrics().averageLuminance < 0.3
    }

    var hasTransparentPixels: Bool {
        ensureIconDerivedMetrics().hasAnyTransparentPixel ?? !isFilledSquare
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

    var isNearBlack: Bool {
        ensureIconDerivedMetrics().isNearBlack
    }
}
