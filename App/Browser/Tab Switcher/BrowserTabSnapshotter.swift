import SwiftUI

@MainActor
enum BrowserTabSnapshotter {

    /// Rendered at card width rather than full size: a card is small, and full
    /// resolution images for every tab are not worth the memory.
    private static let targetWidth: CGFloat = 240

    /// Captures what is on screen right now. Called as the user leaves a page,
    /// which is the only moment that page is available to snapshot.
    ///
    /// `contentTop` is where the page's own content begins, reported by the
    /// page itself: the chrome above it is cropped away so a card shows the
    /// page rather than the navigation bar.
    static func captureVisiblePage(contentTop: CGFloat) -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first, window.bounds.width > 0 else { return nil }

        let top = max(0, min(contentTop, window.bounds.height))
        let scale = targetWidth / window.bounds.width
        let height = window.bounds.height - top
        guard height > 0 else { return nil }

        let size = CGSize(width: targetWidth, height: height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // Drawn shifted up so the chrome falls off the top of the canvas.
            window.drawHierarchy(
                in: CGRect(
                    x: 0,
                    y: -top * scale,
                    width: targetWidth,
                    height: window.bounds.height * scale
                ),
                afterScreenUpdates: false
            )
        }
    }
}
