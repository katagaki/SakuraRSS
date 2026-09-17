import SwiftUI

@MainActor
enum BrowserTabSnapshotter {

    /// Points, not pixels: the renderer draws at the display's scale.
    private static let targetWidth: CGFloat = 200

    /// See `captureVisiblePage`.
    private static let maximumScale: CGFloat = 2

    /// Captures the safe area of what is on screen right now.
    static func captureVisiblePage() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first, window.bounds.width > 0 else { return nil }

        let insets = window.safeAreaInsets
        let scale = targetWidth / window.bounds.width
        let height = window.bounds.height - insets.top - insets.bottom
        guard height > 0 else { return nil }

        let size = CGSize(width: targetWidth, height: height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        // Capped, not the display's own scale: `drawHierarchy` rasterises the
        // whole window in software on the main thread, and its cost runs with
        // the pixel count. A 3x card is invisibly sharper than a 2x one and
        // costs more than twice as much to draw, right as the tap lands.
        // traitCollection rather than screen: visionOS has no UIScreen.
        format.scale = min(window.traitCollection.displayScale, maximumScale)
        // No alpha to blend or carry: the page behind is opaque anyway.
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // Drawn shifted up so the status bar falls off the top of the
            // canvas; the home indicator runs off the bottom.
            window.drawHierarchy(
                in: CGRect(
                    x: 0,
                    y: -insets.top * scale,
                    width: targetWidth,
                    height: window.bounds.height * scale
                ),
                afterScreenUpdates: false
            )
        }
    }
}
