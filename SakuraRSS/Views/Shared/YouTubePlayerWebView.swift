import SwiftUI
import WebKit

struct YouTubePlayerWebView: UIViewRepresentable {

    let urlString: String
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval
    @Binding var webView: WKWebView?
    @Binding var isAd: Bool
    @Binding var advertiserURL: URL?
    @Binding var videoAspectRatio: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPlaying: $isPlaying,
            currentTime: $currentTime,
            duration: $duration,
            isAd: $isAd,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        // swiftlint:disable line_length
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        // swiftlint:enable line_length
        webView.isUserInteractionEnabled = false
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        DispatchQueue.main.async {
            self.webView = webView
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidateObserver()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isPlaying: Bool
        @Binding var currentTime: TimeInterval
        @Binding var duration: TimeInterval
        @Binding var isAd: Bool
        @Binding var advertiserURL: URL?
        @Binding var videoAspectRatio: CGFloat
        private var playbackObserver: Timer?

        init(
            isPlaying: Binding<Bool>,
            currentTime: Binding<TimeInterval>,
            duration: Binding<TimeInterval>,
            isAd: Binding<Bool>,
            advertiserURL: Binding<URL?>,
            videoAspectRatio: Binding<CGFloat>
        ) {
            _isPlaying = isPlaying
            _currentTime = currentTime
            _duration = duration
            _isAd = isAd
            _advertiserURL = advertiserURL
            _videoAspectRatio = videoAspectRatio
        }

        func invalidateObserver() {
            playbackObserver?.invalidate()
            playbackObserver = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectStyles(into: webView)
            unmuteVideo(in: webView)
            startPlaybackObserver(for: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            let host = url.host?.lowercased() ?? ""

            // Allow YouTube and Google auth navigation
            if host.contains("youtube.com") || host.contains("youtu.be")
                || host.contains("google.com") || host.contains("accounts.google.com")
                || host.contains("consent.youtube.com") {
                return .allow
            }

            // Block external navigation
            return .cancel
        }

        private func unmuteVideo(in webView: WKWebView) {
            let script = """
            (function() {
                function unmute() {
                    var video = document.querySelector('video');
                    if (video) { video.muted = false; }
                }
                unmute();
                var observer = new MutationObserver(function() { unmute(); });
                observer.observe(document.body, { childList: true, subtree: true });
                setTimeout(function() { observer.disconnect(); }, 5000);
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func injectStyles(into webView: WKWebView) {
            let css = YouTubePlayerStyles.css
            let script = YouTubePlayerStyles.injectionScript(css: css)
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func startPlaybackObserver(for webView: WKWebView) {
            playbackObserver?.invalidate()
            playbackObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                let script = """
                (function() {
                    var video = document.querySelector('video');
                    if (!video) return null;
                    var player = document.querySelector('.html5-video-player');
                    var isAd = player ? player.classList.contains('ad-showing') : false;
                    var advLink = document.querySelector('.ytp-ad-visit-advertiser-button, \
                .ytp-ad-button, a[class*="visit-advertiser"], .ytp-ad-overlay-link');
                    var advURL = advLink ? (advLink.href || advLink.getAttribute('href') || '') : '';
                    var vw = video.videoWidth || 0;
                    var vh = video.videoHeight || 0;
                    return {
                        playing: !video.paused,
                        currentTime: video.currentTime,
                        duration: video.duration || 0,
                        isAd: isAd,
                        advertiserURL: advURL,
                        videoWidth: vw,
                        videoHeight: vh
                    };
                })();
                """
                webView.evaluateJavaScript(script) { result, _ in
                    if let dict = result as? [String: Any] {
                        DispatchQueue.main.async {
                            if let playing = dict["playing"] as? Bool {
                                self?.isPlaying = playing
                            }
                            if let time = dict["currentTime"] as? Double {
                                self?.currentTime = time
                            }
                            if let dur = dict["duration"] as? Double, dur > 0 {
                                self?.duration = dur
                            }
                            if let ad = dict["isAd"] as? Bool {
                                self?.isAd = ad
                            }
                            if let urlStr = dict["advertiserURL"] as? String, !urlStr.isEmpty {
                                self?.advertiserURL = URL(string: urlStr)
                            } else {
                                self?.advertiserURL = nil
                            }
                            if let vw = dict["videoWidth"] as? Double,
                               let vh = dict["videoHeight"] as? Double,
                               vw > 0, vh > 0 {
                                let ratio = CGFloat(vw / vh)
                                if abs(ratio - (self?.videoAspectRatio ?? 0)) > 0.01 {
                                    withAnimation(.smooth(duration: 0.3)) {
                                        self?.videoAspectRatio = ratio
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Styles

enum YouTubePlayerStyles {

    static let css = """
    * { margin: 0 !important; padding: 0 !important; }
    body { overflow: hidden !important; background: #000 !important; }
    #player, .html5-video-player, video {
        position: fixed !important;
        top: 0 !important;
        left: 0 !important;
        width: 100vw !important;
        height: 100vh !important;
        z-index: 999999 !important;
    }
    ytd-app, #content, #page-manager, ytd-watch-flexy,
    #columns, #primary, #primary-inner, #player-container-outer,
    #player-container-inner, #player-container,
    #movie_player, .html5-video-container {
        position: fixed !important;
        top: 0 !important; left: 0 !important;
        width: 100vw !important; height: 100vh !important;
        max-width: none !important; max-height: none !important;
        min-width: 0 !important; min-height: 0 !important;
        margin: 0 !important; padding: 0 !important;
        overflow: hidden !important;
    }
    #secondary, #related, #comments, #info, #meta,
    #above-the-fold, #below, ytd-watch-metadata,
    #masthead-container, #guide, ytd-masthead,
    ytd-mini-guide-renderer, #chat,
    .ytp-chrome-top, .ytp-title, .ytp-title-text,
    .ytp-overflow-button, .ytp-settings-button,
    .ytp-share-button, .ytp-watch-later-button,
    header, ytm-mobile-topbar-renderer,
    .player-controls-top,
    .ytp-pause-overlay, .ytp-endscreen-content,
    .ytp-chrome-bottom, .ytp-gradient-bottom,
    .ytp-gradient-top, ytd-engagement-panel-section-list-renderer,
    tp-yt-app-drawer, #description, #actions,
    ytd-merch-shelf-renderer, ytd-info-panel-content-renderer,
    .ytd-watch-next-secondary-results-renderer,
    #chips, #header, .ytd-rich-grid-renderer,
    ytd-feed-filter-chip-bar-renderer,
    ytd-compact-promoted-video-renderer,
    .ytp-ce-element, .ytp-cards-teaser,
    .ytp-paid-content-overlay, .iv-branding,
    .ytp-youtube-button, .ytp-watermark,
    tp-yt-paper-dialog, ytd-popup-container,
    ytd-consent-bump-v2-lightbox,
    .ytp-ad-visit-advertiser-button,
    .ytp-visit-advertiser-link, .ytp-ad-overlay-link,
    [class*="visit-advertiser"], .ytp-ad-text,
    .ytp-ad-progress, .ytp-ad-progress-list {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
        width: 0 !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }
    .ytp-skip-ad-button, .ytp-ad-skip-button,
    .ytp-ad-skip-button-modern, .ytp-ad-skip-button-container,
    button[class*="skip"] {
        display: flex !important;
        visibility: visible !important;
        align-items: center !important;
        justify-content: center !important;
        position: fixed !important;
        bottom: 0 !important;
        left: 0 !important;
        width: 100vw !important;
        height: 48px !important;
        opacity: 1 !important;
        pointer-events: auto !important;
        z-index: 9999999 !important;
        background: rgba(0, 0, 0, 0.8) !important;
        color: #fff !important;
        font-size: 16px !important;
        border: none !important;
        border-radius: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
        box-sizing: border-box !important;
    }
    .ytp-skip-ad-button *, .ytp-ad-skip-button *,
    .ytp-ad-skip-button-modern *, .ytp-ad-skip-button-container *,
    button[class*="skip"] * {
        border-radius: 0 !important;
    }
    """

    static func injectionScript(css: String) -> String {
        """
        (function() {
            var style = document.createElement('style');
            style.textContent = `\(css)`;
            document.head.appendChild(style);

            // Re-apply after dynamic content loads
            var observer = new MutationObserver(function() {
                if (!document.getElementById('sakura-yt-style')) {
                    var s = document.createElement('style');
                    s.id = 'sakura-yt-style';
                    s.textContent = `\(css)`;
                    document.head.appendChild(s);
                }
            });
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
    }
}

// MARK: - Premium Check

final class PremiumCheckDelegate: NSObject, WKNavigationDelegate {
    private let completion: (Bool) -> Void
    private var hasCompleted = false

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        // Check for YouTube Premium by looking for premium membership
        // indicators in YouTube's page data
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
