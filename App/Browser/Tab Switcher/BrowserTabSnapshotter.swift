import SwiftUI

@MainActor
enum BrowserTabSnapshotter {

    /// Rendered at card width rather than full size: a card is small, and full
    /// resolution images for every tab are not worth the memory.
    private static let targetWidth: CGFloat = 240

    /// Captures the safe area of what is on screen right now. Called as the
    /// user leaves a page, which is the only moment that page is available to
    /// snapshot.
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
        format.scale = 1
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
