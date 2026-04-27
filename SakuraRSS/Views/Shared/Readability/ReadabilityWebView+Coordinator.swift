import WebKit
import SwiftUI

extension ReadabilityWebView {

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        @Binding var isLoading: Bool
        var lastReloadTrigger: Int = 0
        private var hasAppliedReadability = false

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            guard scheme == "https" || scheme == "http" || scheme == "about" else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            hasAppliedReadability = false
            Task { @MainActor in
                isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            guard !hasAppliedReadability else {
                Task { @MainActor in
                    isLoading = false
                }
                return
            }
            webView.evaluateJavaScript(ReadabilityScript.runScript) { [weak self] _, _ in
                guard let self else { return }
                if !self.hasAppliedReadability {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                }
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            Task { @MainActor in
                isLoading = false
            }
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!,
                     withError _: Error) {
            Task { @MainActor in
                isLoading = false
            }
        }

        func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == ReadabilityScript.messageHandlerName else { return }
            if let payload = message.body as? [String: Any],
               (payload["ok"] as? Bool) == true {
                hasAppliedReadability = true
            }
            Task { @MainActor in
                isLoading = false
            }
        }
    }
}
