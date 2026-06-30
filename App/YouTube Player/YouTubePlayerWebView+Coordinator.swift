import AVFoundation
import SwiftUI
import WebKit
import Hanami

extension YouTubePlayerWebView {

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let autoplay: Bool
        @Binding var isPlaying: Bool
        @Binding var isAd: Bool
        @Binding var isAdSkippable: Bool
        @Binding var advertiserURL: URL?
        @Binding var videoAspectRatio: CGFloat
        @Binding var isPiP: Bool
        let chapters: Binding<[YouTubeChapter]>?
        let onTimeUpdate: ((TimeInterval) -> Void)?
        let onDurationUpdate: ((TimeInterval) -> Void)?
        private var chapterRetryCount = 0
        private var chaptersLoaded = false
        private var hasArmedAutoplay = false

        init(
            autoplay: Bool,
            isPlaying: Binding<Bool>,
            isAd: Binding<Bool>,
            isAdSkippable: Binding<Bool>,
            advertiserURL: Binding<URL?>,
            videoAspectRatio: Binding<CGFloat>,
            isPiP: Binding<Bool>,
            chapters: Binding<[YouTubeChapter]>?,
            onTimeUpdate: ((TimeInterval) -> Void)?,
            onDurationUpdate: ((TimeInterval) -> Void)?
        ) {
            self.autoplay = autoplay
            _isPlaying = isPlaying
            _isAd = isAd
            _isAdSkippable = isAdSkippable
            _advertiserURL = advertiserURL
            _videoAspectRatio = videoAspectRatio
            _isPiP = isPiP
            self.chapters = chapters
            self.onTimeUpdate = onTimeUpdate
            self.onDurationUpdate = onDurationUpdate
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectStyles(into: webView)
            unmuteVideo(in: webView)
            armAutoplayIfNeeded(in: webView)
            if !chaptersLoaded {
                extractChapters(from: webView)
            }
        }

        private func armAutoplayIfNeeded(in webView: WKWebView) {
            guard autoplay, !hasArmedAutoplay else { return }
            hasArmedAutoplay = true
            webView.evaluateJavaScript(
                "window.__yt && window.__yt.armAutoplay && window.__yt.armAutoplay(12000);",
                completionHandler: nil
            )
        }

        private func extractChapters(from webView: WKWebView) {
            guard chapters != nil, !chaptersLoaded else { return }
            webView.evaluateJavaScript(YouTubePlayerScripts.extractChapters) { [weak self] result, _ in
                guard let self else { return }
                let parsed = Self.parseChapters(from: result)
                DispatchQueue.main.async {
                    guard !self.chaptersLoaded else { return }
                    if !parsed.isEmpty {
                        self.chaptersLoaded = true
                        self.chapters?.wrappedValue = parsed
                    } else if self.chapterRetryCount < 3 {
                        self.chapterRetryCount += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            self?.extractChapters(from: webView)
                        }
                    }
                }
            }
        }

        private static func parseChapters(from result: Any?) -> [YouTubeChapter] {
            guard let array = result as? [[String: Any]] else { return [] }
            return array.enumerated().compactMap { index, entry in
                guard let title = entry["title"] as? String, !title.isEmpty,
                      let start = entry["startSeconds"] as? Double else { return nil }
                return YouTubeChapter(id: index, title: title, startTime: start)
            }
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
                if url.path.hasPrefix("/shorts/") {
                    let normalized = YouTubePlayerWebView.normalizedURL(url)
                    if normalized != url {
                        DispatchQueue.main.async {
                            webView.load(URLRequest(url: normalized))
                        }
                        return .cancel
                    }
                }
                return .allow
            }

            return .cancel
        }

        @MainActor
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "ytDebug" {
                log("YT JS", "\(message.body)")
                return
            }
            if message.name == YouTubePlayerScripts.pipMessageHandlerName {
                guard let state = message.body as? String else { return }
                let entered = (state == "enter")
                isPiP = entered
                return
            }
            if message.name == YouTubePlayerScripts.playbackMessageHandlerName,
               let event = PlaybackEvent(message: message) {
                apply(event)
            }
        }

        @MainActor
        private func apply(_ event: PlaybackEvent) {
            switch event.kind {
            case .play, .playing:
                isPlaying = true
                applyTimeAndDuration(event)
            case .pause, .buffering, .seek, .time:
                if event.kind == .pause { isPlaying = false }
                applyCurrentTime(event)
            case .ended:
                isPlaying = false
            case .duration:
                applyDuration(event)
            case .rate:
                break
            case .meta:
                applyMeta(event)
            case .advertisement:
                applyAdvertisement(event)
            }
        }

        @MainActor
        private func applyCurrentTime(_ event: PlaybackEvent) {
            if let time = event.currentTime { onTimeUpdate?(time) }
        }

        @MainActor
        private func applyDuration(_ event: PlaybackEvent) {
            if let eventDuration = event.duration, eventDuration > 0 {
                onDurationUpdate?(eventDuration)
            }
        }

        @MainActor
        private func applyTimeAndDuration(_ event: PlaybackEvent) {
            applyCurrentTime(event)
            applyDuration(event)
        }

        @MainActor
        private func applyMeta(_ event: PlaybackEvent) {
            if let eventDuration = event.duration, eventDuration > 0 { onDurationUpdate?(eventDuration) }
            if let width = event.videoWidth, let height = event.videoHeight,
               width > 0, height > 0 {
                let ratio = CGFloat(width / height)
                if abs(ratio - videoAspectRatio) > 0.01 {
                    videoAspectRatio = ratio
                }
            }
        }

        @MainActor
        private func applyAdvertisement(_ event: PlaybackEvent) {
            isAd = event.isAd ?? false
            isAdSkippable = event.adSkippable ?? false
            if let urlStr = event.advertiserURL, !urlStr.isEmpty {
                advertiserURL = URL(string: urlStr)
            } else {
                advertiserURL = nil
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
    }
}
