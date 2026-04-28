import Foundation
import WebKit

/// Loads a URL in a `WKWebView` and returns the fully-hydrated HTML after JS runs.
@MainActor
final class PetalWebViewLoader: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func loadHTML(from url: URL) async -> String? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let config = WKWebViewConfiguration()
            config.suppressesIncrementalRendering = true
            let webView = WKWebView(
                frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                configuration: config
            )
            webView.customUserAgent = sakuraUserAgent
            webView.navigationDelegate = self
            self.webView = webView
            webView.load(URLRequest(url: url))

            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.handleTimeout()
            }
        }
    }

    private func handleTimeout() {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cleanup()
        continuation.resume(returning: nil)
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        timeoutTask?.cancel()
        timeoutTask = nil
        Task {
            // Let client-side hydration run before snapshotting the DOM.
            try? await Task.sleep(for: .seconds(2))
            self.extractHTML()
        }
    }

    func webView(
        _: WKWebView,
        didFail _: WKNavigation!,
        withError _: Error
    ) {
        finishWithNil()
    }

    func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError _: Error
    ) {
        finishWithNil()
    }

    private func finishWithNil() {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cleanup()
        continuation.resume(returning: nil)
    }

    private func extractHTML() {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let webView else {
            continuation.resume(returning: nil)
            return
        }
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, _ in
            self?.cleanup()
            continuation.resume(returning: result as? String)
        }
    }
}
