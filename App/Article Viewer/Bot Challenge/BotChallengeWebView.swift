import SwiftUI
import WebKit
import Hanami

/// Uses the default data store and user agent to match `WebViewExtractor`,
/// since clearance cookies are bound to the user agent that earned them.
struct BotChallengeWebView: UIViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool
    let onCleared: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, onCleared: onCleared)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    static func dismantleUIView(_: WKWebView, coordinator: Coordinator) {
        coordinator.stopPolling()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        let onCleared: () -> Void
        weak var webView: WKWebView?
        private var pollingTask: Task<Void, Never>?

        init(isLoading: Binding<Bool>, onCleared: @escaping () -> Void) {
            _isLoading = isLoading
            self.onCleared = onCleared
        }

        func stopPolling() {
            pollingTask?.cancel()
            pollingTask = nil
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            isLoading = false
            guard pollingTask == nil else { return }
            pollingTask = Task { [weak self] in
                await self?.pollUntilCleared()
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            isLoading = false
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            isLoading = false
        }

        private func pollUntilCleared() async {
            while !Task.isCancelled {
                if let html = try? await webView?.evaluateJavaScript(
                    "document.documentElement.outerHTML"
                ) as? String, !BotChallengeDetector.looksLikeChallenge(html) {
                    pollingTask = nil
                    onCleared()
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
