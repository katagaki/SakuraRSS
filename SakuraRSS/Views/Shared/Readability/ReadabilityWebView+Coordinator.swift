import WebKit
import SwiftUI

extension ReadabilityWebView {

    final class Coordinator: NSObject, WKNavigationDelegate {

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
            guard navigationAction.request.url?.scheme?.lowercased() == "https" else {
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
            webView.evaluateJavaScript(ReadabilityScript.runScript) { [weak self] result, _ in
                guard let self else { return }
                if (result as? Bool) == true {
                    self.hasAppliedReadability = true
                }
                Task { @MainActor in
                    self.isLoading = false
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
    }
}
