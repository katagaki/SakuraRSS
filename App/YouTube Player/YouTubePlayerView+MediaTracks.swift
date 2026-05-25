import SwiftUI
import WebKit
import Hanami

extension YouTubePlayerView {

    /// Forces the original (non-dubbed) audio via the MSE player's
    /// `setAudioTrack()`. The track list can be empty right after playback
    /// starts, so retry until it resolves.
    func forceOriginalAudio(retriesRemaining: Int = 8) {
        // Only the desktop MSE player (Mac Catalyst) exposes switchable audio
        // tracks; the mobile site used on iOS serves a single baked-in track.
        guard YouTubePlayerWebView.youTubeUserAgent != nil else { return }
        guard !didForceOriginalAudio, let webView else { return }
        webView.evaluateJavaScript(YouTubePlayerScripts.forceOriginalAudioTrack) { [self] result, _ in
            let status = (result as? String) ?? "none"
            DispatchQueue.main.async {
                switch status {
                case "pending":
                    if retriesRemaining > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            self.forceOriginalAudio(retriesRemaining: retriesRemaining - 1)
                        }
                    }
                default:
                    // "switched", "original", or "none" — resolved.
                    self.didForceOriginalAudio = true
                }
            }
        }
    }
}
