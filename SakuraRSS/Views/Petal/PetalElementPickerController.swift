import Observation
import WebKit

/// Bridges Swift calls into JS so the breadcrumb can drive in-page selection.
@MainActor
@Observable
final class PetalElementPickerController {

    weak var webView: WKWebView?

    func selectAncestor(levelsUp: Int) {
        webView?.evaluateJavaScript("window.petalSelectAncestor(\(levelsUp))")
    }

    func selectChild(atIndex index: Int) {
        webView?.evaluateJavaScript("window.petalSelectChild(\(index))")
    }
}
