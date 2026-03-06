import UIKit

// MARK: - Blank Padding Trimming

enum BlankPaddingTrimmer {

    // swiftlint:disable cyclomatic_complexity for_where function_body_length
    /// Crops transparent or near-white padding from a CGImage.
    static func trim(_ cgImage: CGImage, tolerance: CGFloat = 0.95) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isBlank(at offset: Int) -> Bool {
            let alpha = CGFloat(pixelData[offset + 3]) / 255.0
            if alpha < 0.1 { return true }
            let red = CGFloat(pixelData[offset]) / 255.0 / alpha
            let green = CGFloat(pixelData[offset + 1]) / 255.0 / alpha
            let blue = CGFloat(pixelData[offset + 2]) / 255.0 / alpha
            return red >= tolerance && green >= tolerance && blue >= tolerance
        }

        var top = 0
        var bottom = height - 1
        var left = 0
        var right = width - 1

        topScan: for yValue in 0..<height {
            for xValue in 0..<width {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break topScan }
            }
            top = yValue + 1
        }

        bottomScan: for yValue in stride(from: height - 1, through: top, by: -1) {
            for xValue in 0..<width {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break bottomScan }
            }
            bottom = yValue - 1
        }

        guard top <= bottom else { return nil }

        leftScan: for xValue in 0..<width {
            for yValue in top...bottom {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break leftScan }
            }
            left = xValue + 1
        }

        rightScan: for xValue in stride(from: width - 1, through: left, by: -1) {
            for yValue in top...bottom {
                if !isBlank(at: (yValue * width + xValue) * bytesPerPixel) { break rightScan }
            }
            right = xValue - 1
        }

        guard left <= right else { return nil }

        let cropWidth = right - left + 1
        let cropHeight = bottom - top + 1

        let minTrim = max(1, min(width, height) / 10)
        guard top >= minTrim || (height - 1 - bottom) >= minTrim ||
              left >= minTrim || (width - 1 - right) >= minTrim else {
            return nil
        }

        guard cropWidth > 0, cropHeight > 0 else { return nil }

        let cropRect = CGRect(x: left, y: top, width: cropWidth, height: cropHeight)
        return cgImage.cropping(to: cropRect)
    }
    // swiftlint:enable cyclomatic_complexity for_where function_body_length
}

extension UIImage {

    /// Returns a copy with transparent/near-white padding cropped, or self if no significant padding.
    @MainActor func trimmed() -> UIImage {
        guard let cgImage,
              let cropped = BlankPaddingTrimmer.trim(cgImage) else {
            return self
        }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
