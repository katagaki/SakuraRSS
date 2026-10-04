import WebKit

/// WebKit moves the web view into its fullscreen window but keeps the frame
/// it had, since SwiftUI turns off its autoresizing, so it's made to fill
/// that window here and handed back to SwiftUI afterwards.
enum YouTubeFullscreenFitter {

    private static var observations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private static var savedTranslatesAutoresizing: [ObjectIdentifier: Bool] = [:]

    static func track(_ webView: WKWebView) {
        let key = ObjectIdentifier(webView)
        guard observations[key] == nil else { return }
        observations[key] = webView.observe(\.fullscreenState, options: [.new]) { webView, _ in
            Task { @MainActor in update(webView) }
        }
    }

    private static func update(_ webView: WKWebView) {
        let key = ObjectIdentifier(webView)
        switch webView.fullscreenState {
        case .enteringFullscreen, .inFullscreen:
            if savedTranslatesAutoresizing[key] == nil {
                savedTranslatesAutoresizing[key] = webView.translatesAutoresizingMaskIntoConstraints
            }
            guard let superview = webView.superview else { return }
            webView.translatesAutoresizingMaskIntoConstraints = true
            webView.autoresizingMask = [.width, .height]
            webView.frame = superview.bounds
        case .notInFullscreen:
            guard let saved = savedTranslatesAutoresizing.removeValue(forKey: key) else { return }
            webView.translatesAutoresizingMaskIntoConstraints = saved
            webView.superview?.needsLayout = true
        default:
            break
        }
    }
}
