import SwiftUI

struct FaviconImage: View {

    let image: UIImage
    let size: CGFloat
    let cornerRadius: CGFloat
    let isCircle: Bool

    init(_ image: UIImage, size: CGFloat = 20, cornerRadius: CGFloat = 3, circle: Bool = false) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius
        self.isCircle = circle
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .if(image.isDark) { view in
                view
                    .padding(2)
                    .background(.white)
            }
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
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
