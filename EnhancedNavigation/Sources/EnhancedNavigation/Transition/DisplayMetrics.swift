import UIKit

public enum DisplayMetrics {

    /// The key window's safe area, which is the region a tab snapshot covers.
    public static var safeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets }
            .first ?? .zero
    }

    /// The window's full height, which the keyboard does not shrink. A page's
    /// clip rect has to stay the size of the display, or its bottom corners
    /// round inside the shrunken layout while the keyboard is up.
    public static var windowHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.bounds.height }
            .max() ?? 0
    }

    /// Approximate display corner radius. UIKit only exposes this privately, so
    /// it is inferred from the top inset: devices with a notch or Dynamic
    /// Island have rounded displays, older flat-top devices do not.
    public static var displayCornerRadius: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .max() ?? 0
        return topInset > 20 ? 55 : 0
    }
}
