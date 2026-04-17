import Observation
import WebKit

/// Bridges Swift → JS calls so the breadcrumb can drive the
/// in-page selection (drilling up to an ancestor or into a
/// direct child of the currently-selected element).
@MainActor
@Observable
final class PetalElementPickerController {

    weak var webView: WKWebView?

    /// Selects the ancestor `levelsUp` steps above the current
    /// selection.  `1` is the immediate parent, `2` the
    /// grandparent, and so on.
    func selectAncestor(levelsUp: Int) {
        webView?.evaluateJavaScript("window.petalSelectAncestor(\(levelsUp))")
    }

    /// Selects the direct child of the current selection at the
    /// given index in the visible-child list sent to Swift.
    func selectChild(atIndex index: Int) {
        webView?.evaluateJavaScript("window.petalSelectChild(\(index))")
    }
}
