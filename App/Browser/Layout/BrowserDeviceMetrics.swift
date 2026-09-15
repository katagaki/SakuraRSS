import SwiftUI

@MainActor
enum BrowserDeviceMetrics {

    /// Approximate display corner radius. UIKit only exposes this privately, so
    /// it is inferred from the top inset: devices with a notch or Dynamic
    /// Island have rounded displays, older flat-top devices do not.
    static var displayCornerRadius: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .max() ?? 0
        return topInset > 20 ? 55 : 0
    }
}
