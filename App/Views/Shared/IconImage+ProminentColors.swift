import SwiftUI
import UIKit

// MARK: - Prominent Colors

extension UIImage {

    /// Up to four most prominent SwiftUI colors, computed once and cached.
    var prominentColors: [Color] {
        let metrics = ensureIconDerivedMetrics()
        guard let stored = metrics.prominentColors, !stored.isEmpty else {
            return [averageColor]
        }
        return stored.compactMap { rgb -> Color? in
            guard rgb.count >= 3 else { return nil }
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
    }

    // swiftlint:disable:next identifier_name
    nonisolated func _rawProminentColors() -> [[Double]]? {
        guard let cgImage = cgImage else { return nil }
        guard let pixelData = Self.samplePixelData(from: cgImage) else { return nil }
        let buckets = Self.bucketPixels(pixelData)
        guard !buckets.isEmpty else { return nil }
        var picked = Self.pickProminentColors(from: buckets)
        if picked.count < 4, let first = picked.first {
            while picked.count < 4 {
                picked.append(first)
            }
        }

        guard !picked.isEmpty else { return nil }
        return picked.map { [$0.red, $0.green, $0.blue] }
    }

    nonisolated fileprivate static func samplePixelData(from cgImage: CGImage) -> [UInt8]? {
        let sampleSize = 32
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
        return pixelData
    }

    fileprivate struct ProminentColorBucket {
        var totalRed: Int = 0
        var totalGreen: Int = 0
        var totalBlue: Int = 0
        var count: Int = 0
    }

    nonisolated fileprivate static func bucketPixels(_ pixelData: [UInt8]) -> [Int: ProminentColorBucket] {
        let sampleSize = 32
        let bits = 4
        let levels = 1 << bits
        let shift = 8 - bits
        var buckets: [Int: ProminentColorBucket] = [:]
        for index in 0..<(sampleSize * sampleSize) {
            let offset = index * 4
            let alpha = pixelData[offset + 3]
            guard alpha > 200 else { continue }
            let red = pixelData[offset]
            let green = pixelData[offset + 1]
            let blue = pixelData[offset + 2]
            let quantizedRed = Int(red) >> shift
            let quantizedGreen = Int(green) >> shift
            let quantizedBlue = Int(blue) >> shift
            let key = (quantizedRed * levels + quantizedGreen) * levels + quantizedBlue
            var bucket = buckets[key, default: ProminentColorBucket()]
            bucket.totalRed += Int(red)
            bucket.totalGreen += Int(green)
            bucket.totalBlue += Int(blue)
            bucket.count += 1
            buckets[key] = bucket
        }
        return buckets
    }

    fileprivate struct PickedColor {
        let red: Double
        let green: Double
        let blue: Double
    }

    nonisolated fileprivate static func pickProminentColors(
        from buckets: [Int: ProminentColorBucket]
    ) -> [PickedColor] {
        let sorted = buckets.values.sorted { $0.count > $1.count }
        var picked: [PickedColor] = []
        let minDistance: Double = 0.18
        for bucket in sorted {
            let avgRed = Double(bucket.totalRed) / Double(bucket.count) / 255.0
            let avgGreen = Double(bucket.totalGreen) / Double(bucket.count) / 255.0
            let avgBlue = Double(bucket.totalBlue) / Double(bucket.count) / 255.0
            let isFarEnough = picked.allSatisfy { existing in
                let dRed = existing.red - avgRed
                let dGreen = existing.green - avgGreen
                let dBlue = existing.blue - avgBlue
                return (dRed * dRed + dGreen * dGreen + dBlue * dBlue).squareRoot() >= minDistance
            }
            if isFarEnough {
                picked.append(PickedColor(red: avgRed, green: avgGreen, blue: avgBlue))
                if picked.count == 4 { break }
            }
        }
        return picked
    }
}
