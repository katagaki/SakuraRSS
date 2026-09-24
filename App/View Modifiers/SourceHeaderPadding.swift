import SwiftUI

struct SourceHeaderPadding: ViewModifier {

    @Environment(\.isBrowserChromeActive) private var isBrowserChromeActive

    /// The browser hides the navigation bar and draws its pages edge to edge,
    /// so the header puts back part of the inset the bar used to provide, and
    /// the same amount again below to keep it centred in its own space.
    private var browserInset: CGFloat {
        guard isBrowserChromeActive else { return 0 }
        return max(BrowserDeviceMetrics.safeAreaInsets.top - 24, 0)
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 4 + browserInset)
            .padding(.bottom, 16 + browserInset)
    }
}

extension View {
    func sourceHeaderPadding() -> some View {
        modifier(SourceHeaderPadding())
    }
}
