import Hanami
import SwiftUI
import WebKit

struct WebPageWebView: NSViewRepresentable {

    let url: URL
    let style: WebPageStyle
    let reloadTrigger: Int
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(style: style, isLoading: $isLoading)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = style.usesPersistentData ? .default() : .nonPersistent()
        for source in style.userScripts {
            configuration.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        context.coordinator.lastReloadTrigger = reloadTrigger
        if let address = style.address(for: url) {
            webView.load(URLRequest(url: address))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard reloadTrigger != context.coordinator.lastReloadTrigger else { return }
        context.coordinator.lastReloadTrigger = reloadTrigger
        if let address = style.address(for: url) {
            webView.load(URLRequest(url: address))
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator _: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {

        let style: WebPageStyle
        @Binding var isLoading: Bool
        var lastReloadTrigger = 0
        private var hasAppliedReaderMode = false

        init(style: WebPageStyle, isLoading: Binding<Bool>) {
            self.style = style
            _isLoading = isLoading
        }

        /// Reading services only ever load over HTTPS, as on iOS.
        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            let isAllowed = style == .page ? scheme == "https" || scheme == "http" : scheme == "https"
            decisionHandler(isAllowed ? .allow : .cancel)
        }

        func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            hasAppliedReaderMode = false
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            guard style == .readerMode, !hasAppliedReaderMode else {
                isLoading = false
                return
            }
            webView.evaluateJavaScript(ReadabilityScript.runScript) { [weak self] result, _ in
                MainActor.assumeIsolated {
                    if (result as? Bool) == true {
                        self?.hasAppliedReaderMode = true
                    }
                    self?.isLoading = false
                }
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            isLoading = false
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            isLoading = false
        }
    }
}
