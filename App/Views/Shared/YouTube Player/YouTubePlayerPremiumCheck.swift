import Foundation
import WebKit

final class PremiumCheckDelegate: NSObject, WKNavigationDelegate {
    private let completion: (Bool) -> Void
    private var hasCompleted = false

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        let script = """
        (function() {
            try {
                var text = document.documentElement.innerHTML;
                if (text.indexOf('"isPremium":true') !== -1) {
                    return true;
                }
                if (text.indexOf('"hasPaidContent":true') !== -1) {
                    return true;
                }
                if (document.querySelector('[is-premium-member]')) {
                    return true;
                }
                return false;
            } catch(e) {
                return false;
            }
        })();
        """

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, !self.hasCompleted else { return }
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self, !self.hasCompleted else { return }
                self.hasCompleted = true
                self.completion((result as? Bool) == true)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(false)
    }
}
