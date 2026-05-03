import Foundation
import WebKit

final class WebViewExtractor: NSObject, WKNavigationDelegate {

    // MARK: - Domain Whitelist

    static func requiresWebView(for url: URL) -> Bool {
        ExtractTextDomains.shouldExtractText(for: url)
    }

    // MARK: - Extraction

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func extractText(from url: URL) async -> String? {
        let html = await loadAndExtractHTML(from: url)
        guard let html, !html.isEmpty else { return nil }
        return ArticleExtractor.extractText(fromHTML: html, baseURL: url)
    }

    private func loadAndExtractHTML(from url: URL) async -> String? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let config = WKWebViewConfiguration()
            config.suppressesIncrementalRendering = true
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView

            webView.load(URLRequest(url: url))

            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
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
        // Give JS frameworks time to hydrate before snapshotting.
        timeoutTask?.cancel()
        timeoutTask = nil
        Task {
            try? await Task.sleep(for: .seconds(2))
            self.extractHTML()
        }
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cleanup()
        continuation.resume(returning: nil)
    }

    func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError _: Error
    ) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cleanup()
        continuation.resume(returning: nil)
    }

    private static let cleanupScript = """
    (function() {
        document.querySelectorAll('.sosumi').forEach(el => el.remove());

        const consentSelectors = [
            '#onetrust-banner-sdk', '#onetrust-consent-sdk',
            '.osano-cm-window', '.qc-cmp2-container',
            '[id*="cookie-banner" i]', '[class*="cookie-banner" i]',
            '[id*="cookie-consent" i]', '[class*="cookie-consent" i]',
            '[id*="cookie-notice" i]', '[class*="cookie-notice" i]',
            '[id*="gdpr" i]', '[class*="gdpr" i]',
            '.fc-consent-root', '#CybotCookiebotDialog',
            '#cookiebanner', '#cookieConsentBanner',
            '#didomi-host', '#didomi-notice',
            '.didomi-popup-view', '.didomi-notice-banner',
            '[id^="didomi-" i]', '[class^="didomi-" i]',
            '.truste_overlay', '.truste_cursheet',
            '.sp-message-container', '.cc-window', '.cc-banner',
            '[aria-label*="consent" i]',
            '[role="dialog"]', '[aria-modal="true"]',
            'dialog[open]'
        ];
        for (const selector of consentSelectors) {
            try {
                document.querySelectorAll(selector).forEach(el => el.remove());
            } catch (_) {}
        }

        // Some consent overlays leave scroll locks on <html>/<body>.
        try {
            document.documentElement.style.overflow = 'auto';
            document.body.style.overflow = 'auto';
            document.documentElement.style.position = '';
            document.body.style.position = '';
        } catch (_) {}

        const all = document.body.querySelectorAll('*');
        for (const el of all) {
            const style = window.getComputedStyle(el);
            if (style.display === 'none'
                || style.visibility === 'hidden'
                || style.opacity === '0'
                || (el.offsetWidth <= 1 && el.offsetHeight <= 1)) {
                el.remove();
            }
        }
        return document.documentElement.outerHTML;
    })()
    """

    private func extractHTML() {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil

        guard let webView else {
            continuation.resume(returning: nil)
            return
        }

        webView.evaluateJavaScript(Self.cleanupScript) { [weak self] result, _ in
            self?.cleanup()
            continuation.resume(returning: result as? String)
        }
    }
}
