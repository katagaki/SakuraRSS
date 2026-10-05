import CoreGraphics

enum BrowserIconMetrics {

    /// One ratio for every feed icon the browser draws. Picking a radius per
    /// call site left the same feed looking squarer in the omnibox than on the
    /// start page.
    static func cornerRadius(for size: CGFloat) -> CGFloat {
        size * 0.25
    }
}
