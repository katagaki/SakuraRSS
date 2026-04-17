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
    @Binding var isPiP: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPlaying: $isPlaying,
            currentTime: $currentTime,
            duration: $duration,
            isAd: $isAd,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio,
            isPiP: $isPiP
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.backgroundPlaybackOverride,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.pipEventBridge,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        controller.add(context.coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.customUserAgent = sakuraUserAgent
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
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: YouTubePlayerScripts.pipMessageHandlerName
        )
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var isPlaying: Bool
        @Binding var currentTime: TimeInterval
        @Binding var duration: TimeInterval
        @Binding var isAd: Bool
        @Binding var advertiserURL: URL?
        @Binding var videoAspectRatio: CGFloat
        @Binding var isPiP: Bool
        nonisolated(unsafe) private var playbackObserver: Timer?

        init(
            isPlaying: Binding<Bool>,
            currentTime: Binding<TimeInterval>,
            duration: Binding<TimeInterval>,
            isAd: Binding<Bool>,
            advertiserURL: Binding<URL?>,
            videoAspectRatio: Binding<CGFloat>,
            isPiP: Binding<Bool>
        ) {
            _isPlaying = isPlaying
            _currentTime = currentTime
            _duration = duration
            _isAd = isAd
            _advertiserURL = advertiserURL
            _videoAspectRatio = videoAspectRatio
            _isPiP = isPiP
        }

        deinit {
            playbackObserver?.invalidate()
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

            if host.contains("youtube.com") || host.contains("youtu.be")
                || host.contains("google.com") || host.contains("accounts.google.com")
                || host.contains("consent.youtube.com") {
                return .allow
            }

            return .cancel
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == YouTubePlayerScripts.pipMessageHandlerName,
                  let state = message.body as? String else { return }
            let entered = (state == "enter")
            Task { @MainActor in
                self.isPiP = entered
            }
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
                    var inPiP = document.pictureInPictureElement === video;
                    return {
                        playing: !video.paused,
                        currentTime: video.currentTime,
                        duration: video.duration || 0,
                        isAd: isAd,
                        advertiserURL: advURL,
                        videoWidth: vw,
                        videoHeight: vh,
                        isPiP: inPiP
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
                            // swiftlint:disable identifier_name
                            if let ad = dict["isAd"] as? Bool {
                                self?.isAd = ad
                            }
                            // swiftlint:enable identifier_name
                            if let urlStr = dict["advertiserURL"] as? String, !urlStr.isEmpty {
                                self?.advertiserURL = URL(string: urlStr)
                            } else {
                                self?.advertiserURL = nil
                            }
                            if let width = dict["videoWidth"] as? Double,
                               let height = dict["videoHeight"] as? Double,
                               width > 0, height > 0 {
                                let ratio = CGFloat(width / height)
                                if abs(ratio - (self?.videoAspectRatio ?? 0)) > 0.01 {
                                    withAnimation(.smooth(duration: 0.3)) {
                                        self?.videoAspectRatio = ratio
                                    }
                                }
                            }
                            if let pip = dict["isPiP"] as? Bool {
                                self?.isPiP = pip
                            }
                        }
                    }
                }
            }
        }
    }
}
