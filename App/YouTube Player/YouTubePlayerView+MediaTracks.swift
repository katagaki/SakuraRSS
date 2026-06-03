import SwiftUI
import WebKit
import Hanami

extension YouTubePlayerView {

    func forceOriginalAudio(retriesRemaining: Int = 8) {
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
                    self.didForceOriginalAudio = true
                }
            }
        }
    }
}
