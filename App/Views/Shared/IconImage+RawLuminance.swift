import SwiftUI
import UIKit

extension UIImage {

    nonisolated func rawHasAnyTransparentPixel() -> Bool {
        guard let cgImage = cgImage else { return false }

        let sampleSize = 64
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

        for index in 0..<(sampleSize * sampleSize) where pixelData[index * 4 + 3] < 200 {
            return true
        }
        return false
    }

    nonisolated func rawIsNearBlack() -> Bool {
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

    nonisolated func rawAverageLuminance() -> CGFloat {
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

            totalLuminance += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            opaquePixelCount += 1
        }

        guard opaquePixelCount > 0 else { return 1.0 }
        return totalLuminance / opaquePixelCount
    }
}
