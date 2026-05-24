import SwiftUI
import WebKit
import Hanami

extension YouTubePlayerView {

    /// Forces the original (non-dubbed) audio via the MSE player's
    /// `setAudioTrack()`. The track list can be empty right after playback
    /// starts, so retry until it resolves.
    func forceOriginalAudio(retriesRemaining: Int = 8) {
        guard !didForceOriginalAudio, let webView else { return }
        webView.evaluateJavaScript(YouTubePlayerScripts.audioTrackDiagnostics) { result, _ in
            // swiftlint:disable:next line_length
            log("YT Audio", "diagnostics retriesRemaining=\(retriesRemaining) \((result as? String) ?? "nil")")
        }
        webView.evaluateJavaScript(YouTubePlayerScripts.forceOriginalAudioTrack) { [self] result, _ in
            let status = (result as? String) ?? "none"
            log("YT Audio", "forceOriginalAudio status=\(status)")
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
