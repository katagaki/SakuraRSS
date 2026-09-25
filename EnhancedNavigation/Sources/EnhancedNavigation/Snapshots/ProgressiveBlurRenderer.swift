import CoreImage.CIFilterBuiltins
import UIKit

/// Blurs an image progressively down from its top edge, so a title row reads
/// over a busy snapshot. Rendered once per image rather than as a live
/// filter: every card in a grid would otherwise re-blur on each frame of a
/// scroll.
public enum ProgressiveBlurRenderer {

    /// In the image's own pixels.
    nonisolated static let radius: Double = 8

    /// How far down the blur reaches, in multiples of the image's width, so it
    /// tracks a title row whatever the card's size.
    nonisolated static let depth: Double = 0.36

    private nonisolated(unsafe) static let cache = NSCache<UIImage, UIImage>()
    private nonisolated static let context = CIContext()

    public static func cached(for image: UIImage) -> UIImage? {
        cache.object(forKey: image)
    }

    public static func render(_ image: UIImage) async -> UIImage? {
        let result = await Task.detached(priority: .userInitiated) {
            blur(image)
        }.value
        if let result {
            cache.setObject(result, forKey: image)
        }
        return result
    }

    private nonisolated static func blur(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        // Core Image's origin is the bottom left, so the top edge is maxY.
        let mask = CIFilter.linearGradient()
        mask.point0 = CGPoint(x: 0, y: extent.maxY)
        mask.point1 = CGPoint(x: 0, y: extent.maxY - extent.width * depth)
        mask.color0 = CIColor.white
        mask.color1 = CIColor.black

        let filter = CIFilter.maskedVariableBlur()
        // Clamped first, or the blur pulls transparent black in at the edges.
        filter.inputImage = input.clampedToExtent()
        filter.mask = mask.outputImage?.cropped(to: extent)
        filter.radius = Float(radius)

        guard let output = filter.outputImage?.cropped(to: extent),
              let rendered = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension UIImage {
    var widthToHeightRatio: CGFloat {
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }
}
