import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// The snapshot again, blurred progressively down from its top edge, so the
/// title row reads over busy pages. Rendered once per snapshot rather than
/// as a live filter: every card in the grid would otherwise re-blur on each
/// frame of a scroll.
struct BrowserTabHeaderBlur: View {

    @Environment(BrowserTabStore.self) private var store
    let tab: BrowserTab
    @State private var blurred: UIImage?

    var body: some View {
        let snapshot = store.snapshots[tab.id]
        GeometryReader { proxy in
            if let blurred {
                Image(uiImage: blurred)
                    .resizable()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.width / BrowserTabHeaderBlurRenderer.aspectRatio(of: blurred)
                    )
            }
        }
        .allowsHitTesting(false)
        .task(id: snapshot.map(ObjectIdentifier.init)) {
            guard let snapshot else {
                blurred = nil
                return
            }
            if let cached = BrowserTabHeaderBlurRenderer.cached(for: snapshot) {
                blurred = cached
                return
            }
            // Cleared first: the previous snapshot's blur, over the new one,
            // shows the old page's title through the header.
            blurred = nil
            blurred = await BrowserTabHeaderBlurRenderer.render(snapshot)
        }
    }
}

enum BrowserTabHeaderBlurRenderer {

    /// In the snapshot's own pixels, which are the card's width at the
    /// renderer's scale.
    nonisolated static let radius: Double = 8

    /// How far down the blur reaches, in multiples of the snapshot's width, so
    /// it tracks the title row whatever the card's size.
    nonisolated static let depth: Double = 0.36

    private nonisolated(unsafe) static let cache = NSCache<UIImage, UIImage>()
    private nonisolated(unsafe) static let context = CIContext()

    static func aspectRatio(of image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

    static func cached(for snapshot: UIImage) -> UIImage? {
        cache.object(forKey: snapshot)
    }

    static func render(_ snapshot: UIImage) async -> UIImage? {
        let result = await Task.detached(priority: .userInitiated) {
            blur(snapshot)
        }.value
        if let result {
            cache.setObject(result, forKey: snapshot)
        }
        return result
    }

    private nonisolated static func blur(_ snapshot: UIImage) -> UIImage? {
        guard let cgImage = snapshot.cgImage else { return nil }
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
        return UIImage(cgImage: rendered, scale: snapshot.scale, orientation: snapshot.imageOrientation)
    }
}
