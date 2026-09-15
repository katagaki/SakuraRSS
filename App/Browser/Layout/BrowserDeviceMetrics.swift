import SwiftUI

@MainActor
enum BrowserDeviceMetrics {

    /// Approximate display corner radius. UIKit only exposes this privately, so
    /// it is inferred from the top inset: devices with a notch or Dynamic
    /// Island have rounded displays, older flat-top devices do not.
    /// Width over height of the screen's safe area, which is the region a
    /// snapshot covers. Shaping the cards to it means a snapshot fills its card
    /// exactly, with no strip of card left over and no distortion when the page
    /// collapses into it.
    static var safeAreaAspectRatio: CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else { return 9.0 / 19.5 }
        let height = window.bounds.height - window.safeAreaInsets.top - window.safeAreaInsets.bottom
        guard height > 0 else { return 9.0 / 19.5 }
        return window.bounds.width / height
    }

    static var displayCornerRadius: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .max() ?? 0
        return topInset > 20 ? 55 : 0
    }
}
