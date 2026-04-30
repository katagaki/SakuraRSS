import SwiftUI
import WebKit

/// Holds the YouTube player's `WKWebView` and playback state across sheet
/// dismissals so audio keeps playing when the player is collapsed into the
/// tab bar bottom accessory.
@MainActor
@Observable
final class YouTubePlayerSession {

    static let shared = YouTubePlayerSession()

    var currentArticle: Article?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var videoTitle: String?
    var channelTitle: String?
    var artworkURL: URL?

    /// The persistent WKWebView. Owned by the session so playback survives
    /// the player view being dismissed.
    @ObservationIgnored
    var webView: WKWebView?

    private init() {}

    func adopt(article: Article) {
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

    func togglePlayPause() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (!video) { return null; }
            if (video.paused) {
                window.__ytUserPaused = false;
                video.play();
            } else {
                window.__ytUserPaused = true;
                video.pause();
            }
            return !video.paused;
        })();
        """
        webView?.evaluateJavaScript(script) { result, _ in
            if let playing = result as? Bool {
                Task { @MainActor in
                    YouTubePlayerSession.shared.isPlaying = playing
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
    }
}
