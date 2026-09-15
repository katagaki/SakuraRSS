import SwiftUI

@MainActor
enum BrowserDeviceMetrics {

    /// Approximate display corner radius. UIKit only exposes this privately, so
    /// it is inferred from the top inset: devices with a notch or Dynamic
    /// Island have rounded displays, older flat-top devices do not.
    /// Width over height of the screen, so a tab card can be shaped like the
    /// page it stands for.
    static var screenAspectRatio: CGFloat {
        guard let bounds = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.bounds })
            .first, bounds.height > 0 else { return 9.0 / 19.5 }
        return bounds.width / bounds.height
    }

    static var displayCornerRadius: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .max() ?? 0
        return topInset > 20 ? 55 : 0
    }
}
