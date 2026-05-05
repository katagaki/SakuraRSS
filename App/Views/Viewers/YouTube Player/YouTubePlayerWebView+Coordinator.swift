import AVFoundation
import SwiftUI
import WebKit

extension YouTubePlayerWebView {

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var isPlaying: Bool
        @Binding var currentTime: TimeInterval
        @Binding var duration: TimeInterval
        @Binding var isAd: Bool
        @Binding var isAdSkippable: Bool
        @Binding var advertiserURL: URL?
        @Binding var videoAspectRatio: CGFloat
        @Binding var isPiP: Bool
        let chapters: Binding<[YouTubeChapter]>?
        private var chapterRetryCount = 0
        private var chaptersLoaded = false

        init(
            isPlaying: Binding<Bool>,
            currentTime: Binding<TimeInterval>,
            duration: Binding<TimeInterval>,
            isAd: Binding<Bool>,
            isAdSkippable: Binding<Bool>,
            advertiserURL: Binding<URL?>,
            videoAspectRatio: Binding<CGFloat>,
            isPiP: Binding<Bool>,
            chapters: Binding<[YouTubeChapter]>?
        ) {
            _isPlaying = isPlaying
            _currentTime = currentTime
            _duration = duration
            _isAd = isAd
            _isAdSkippable = isAdSkippable
            _advertiserURL = advertiserURL
            _videoAspectRatio = videoAspectRatio
            _isPiP = isPiP
            self.chapters = chapters
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectStyles(into: webView)
            unmuteVideo(in: webView)
            if !chaptersLoaded {
                extractChapters(from: webView)
            }
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

        nonisolated func userContentController(
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
                Task { @MainActor in self.isPiP = entered }
                return
            }
            if message.name == YouTubePlayerScripts.playbackMessageHandlerName,
               let event = PlaybackEvent(message: message) {
                Task { @MainActor in self.apply(event) }
            }
        }

        @MainActor
        private func apply(_ event: PlaybackEvent) {
            switch event.kind {
            case .play, .playing:
                isPlaying = true
                if let time = event.currentTime { currentTime = time }
                if let eventDuration = event.duration, eventDuration > 0 { duration = eventDuration }
            case .pause:
                isPlaying = false
                if let time = event.currentTime { currentTime = time }
            case .buffering:
                if let time = event.currentTime { currentTime = time }
            case .ended:
                isPlaying = false
            case .seek, .time:
                if let time = event.currentTime { currentTime = time }
            case .duration:
                if let eventDuration = event.duration, eventDuration > 0 { duration = eventDuration }
            case .rate:
                break
            case .meta:
                if let eventDuration = event.duration, eventDuration > 0 { duration = eventDuration }
                if let width = event.videoWidth, let height = event.videoHeight,
                   width > 0, height > 0 {
                    let ratio = CGFloat(width / height)
                    if abs(ratio - videoAspectRatio) > 0.01 {
                        videoAspectRatio = ratio
                    }
                }
            case .ad:
                isAd = event.isAd ?? false
                isAdSkippable = event.adSkippable ?? false
                if let urlStr = event.advertiserURL, !urlStr.isEmpty {
                    advertiserURL = URL(string: urlStr)
                } else {
                    advertiserURL = nil
                }
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
