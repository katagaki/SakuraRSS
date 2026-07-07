import SwiftUI
import WebKit
import Hanami

/// Holds the YouTube player's `WKWebView` and playback state across sheet
/// dismissals so audio keeps playing when the player is collapsed into the
/// tab bar bottom accessory.
@MainActor
@Observable
final class YouTubePlayerSession {

    static let shared = YouTubePlayerSession(isPrimary: true)

    var currentArticle: Article?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var videoTitle: String?
    var channelTitle: String?
    var artworkURL: URL?

    /// Cached aspect ratio for the current video so reopening the player
    /// sheet doesn't have to wait for the JS observer to remeasure.
    @ObservationIgnored
    var videoAspectRatio: CGFloat = 16 / 9

    /// The persistent WKWebView. Owned by the session so playback survives
    /// the player view being dismissed.
    @ObservationIgnored
    var webView: WKWebView?

    /// Whether this is the app-wide shared session. Detached-window instances
    /// are not primary and skip mutual-exclusion with `AudioPlayer.shared`.
    @ObservationIgnored
    let isPrimary: Bool

    init(isPrimary: Bool = false) {
        self.isPrimary = isPrimary
    }

    func adopt(article: Article) {
        if isPrimary, AudioPlayer.shared.currentArticleID != nil {
            AudioPlayer.shared.stop()
        }
        if let current = currentArticle, current.id != article.id || current.url != article.url {
            tearDownWebView()
        }
        currentArticle = article
    }

    func clear() {
        tearDownWebView()
        currentArticle = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        videoTitle = nil
        channelTitle = nil
        artworkURL = nil
    }

    var isActive: Bool { webView != nil }

    func togglePlayPause() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (!video) { return null; }
            var mediaMissing = (window.__yt && window.__yt.mediaMissing)
                ? window.__yt.mediaMissing(video)
                : (video.readyState === 0 && !video.currentSrc && !video.srcObject);
            if (video.paused || mediaMissing) {
                if (window.__yt) {
                    window.__yt.autoplayBlocked = false;
                    window.__yt.userPaused = false;
                    window.__yt.exitedPiPRecently = false;
                }
                // A play() the page never observed leaves the element
                // un-paused with no media; cycle pause() so the mobile watch
                // page sees a fresh play event and attaches the media.
                if (!video.paused) { video.pause(); }
                var playPromise = video.play();
                if (playPromise && typeof playPromise.catch === 'function') {
                    playPromise.catch(function(){});
                }
            } else {
                if (window.__yt) { window.__yt.userPaused = true; }
                video.pause();
            }
            return !video.paused;
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            if let playing = result as? Bool {
                Task { @MainActor in
                    self?.isPlaying = playing
                }
            }
        }
    }

    func play() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (!video) { return null; }
            if (window.__yt) {
                window.__yt.autoplayBlocked = false;
                window.__yt.userPaused = false;
                window.__yt.exitedPiPRecently = false;
            }
            var mediaMissing = (window.__yt && window.__yt.mediaMissing)
                ? window.__yt.mediaMissing(video)
                : (video.readyState === 0 && !video.currentSrc && !video.srcObject);
            if (!video.paused && mediaMissing) { video.pause(); }
            var playPromise = video.play();
            if (playPromise && typeof playPromise.catch === 'function') {
                playPromise.catch(function(){});
            }
            return !video.paused;
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            if let playing = result as? Bool {
                Task { @MainActor in
                    self?.isPlaying = playing
                }
            }
        }
    }

    func pause() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (!video) { return null; }
            if (window.__yt) { window.__yt.userPaused = true; }
            video.pause();
            return !video.paused;
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            if let playing = result as? Bool {
                Task { @MainActor in
                    self?.isPlaying = playing
                }
            }
        }
    }

    private func tearDownWebView() {
        let pauseScript = """
        (function() {
            var v = document.querySelector('video');
            if (v) { v.pause(); v.src = ''; v.load(); }
        })();
        """
        webView?.evaluateJavaScript(pauseScript, completionHandler: nil)
        webView?.stopLoading()
        webView = nil
        videoAspectRatio = 16 / 9
    }
}
