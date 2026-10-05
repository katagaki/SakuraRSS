import AppKit
import SwiftUI
import WebKit

/// Holds the playing web view under the panel's controls. Reopening the
/// video adopts the same web view, which takes it out of here, so that's
/// reported for the panel to close.
final class YouTubePictureInPictureContentView: NSView {

    var onWebViewTaken: (() -> Void)?
    private(set) weak var webView: WKWebView?
    private let controlsView: NSView
    private var isReleasingWebView = false

    init(controls: some View) {
        controlsView = NSHostingView(rootView: controls)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        controlsView.frame = bounds
        controlsView.autoresizingMask = [.width, .height]
        addSubview(controlsView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func hold(_ webView: WKWebView) {
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = bounds
        webView.autoresizingMask = [.width, .height]
        addSubview(webView, positioned: .below, relativeTo: controlsView)
        self.webView = webView
    }

    func releaseWebView() -> WKWebView? {
        guard let webView else { return nil }
        isReleasingWebView = true
        webView.removeFromSuperview()
        isReleasingWebView = false
        return webView
    }

    override func willRemoveSubview(_ subview: NSView) {
        super.willRemoveSubview(subview)
        guard subview === webView else { return }
        webView = nil
        if !isReleasingWebView {
            DispatchQueue.main.async { [weak self] in
                self?.onWebViewTaken?()
            }
        }
    }
}
