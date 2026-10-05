import Foundation
import WebKit

@MainActor
public final class WebViewExtractor: NSObject, WKNavigationDelegate {

    // MARK: - Domain Whitelist

    public nonisolated static func requiresWebView(for url: URL) -> Bool {
        SiteContentExtractorRegistry.extractor(for: url)?.requiresWebView ?? false
    }

    // MARK: - Extraction

    public nonisolated struct Extraction: Sendable {
        public var text: String?
        public var pageTitle: String?
        public var challenged: Bool
    }

    private enum RenderedPage {
        case html(String)
        case challenged
        case failed
    }

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<RenderedPage, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?

    private static let hydrationDelay: Duration = .seconds(2)
    private static let challengePollInterval: Duration = .seconds(1)
    private static let challengeDeadline: Duration = .seconds(8)

    /// Loads the page on the main actor, then parses the rendered HTML off it.
    public nonisolated static func extractText(
        from url: URL, excludeTitle: String? = nil
    ) async -> String? {
        await extract(from: url, excludeTitle: excludeTitle).text
    }

    public nonisolated static func extract(
        from url: URL, excludeTitle: String? = nil
    ) async -> Extraction {
        switch await loadRenderedHTML(from: url) {
        case .html(let html) where !html.isEmpty:
            let text = await HTMLContentExtractor.extractText(
                offMainActorFromHTML: html, baseURL: url, excludeTitle: excludeTitle
            )
            let pageTitle = await HTMLContentExtractor.pageTitle(offMainActorFromHTML: html)
            return Extraction(text: text, pageTitle: pageTitle, challenged: false)
        case .challenged:
            return Extraction(text: nil, pageTitle: nil, challenged: true)
        default:
            return Extraction(text: nil, pageTitle: nil, challenged: false)
        }
    }

    @MainActor
    private static func loadRenderedHTML(from url: URL) async -> RenderedPage {
        await WebViewExtractor().loadAndExtractHTML(from: url)
    }

    private func loadAndExtractHTML(from url: URL) async -> RenderedPage {
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
        finish(returning: .failed)
    }

    private func finish(returning page: RenderedPage) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        snapshotTask?.cancel()
        snapshotTask = nil
        cleanup()
        continuation.resume(returning: page)
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }

    // MARK: - WKNavigationDelegate

    public func webView(_: WKWebView, didFinish _: WKNavigation!) {
        // Bot challenges reload the page once solved, so didFinish can fire
        // again while the first snapshot is still waiting.
        guard snapshotTask == nil else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        snapshotTask = Task { [weak self] in
            await self?.waitForArticleAndSnapshot()
        }
    }

    public func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        guard snapshotTask == nil else { return }
        finish(returning: .failed)
    }

    public func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError _: Error
    ) {
        guard snapshotTask == nil else { return }
        finish(returning: .failed)
    }

    private func waitForArticleAndSnapshot() async {
        try? await Task.sleep(for: Self.hydrationDelay)
        let deadline = ContinuousClock.now + Self.challengeDeadline
        while !Task.isCancelled {
            guard let html = await evaluate(Self.outerHTMLScript) else {
                finish(returning: .failed)
                return
            }
            if await !BotChallengeDetector.looksLikeChallengeOffMainActor(html) {
                let cleanedHTML = await evaluate(Self.cleanupScript)
                finish(returning: cleanedHTML.map(RenderedPage.html) ?? .failed)
                return
            }
            guard ContinuousClock.now < deadline else {
                log("WebViewExtractor", "Bot challenge did not clear before the deadline")
                finish(returning: .challenged)
                return
            }
            try? await Task.sleep(for: Self.challengePollInterval)
        }
    }

    private func evaluate(_ script: String) async -> String? {
        guard let webView else { return nil }
        return try? await webView.evaluateJavaScript(script) as? String
    }

    private static let outerHTMLScript = "document.documentElement.outerHTML"

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
}
