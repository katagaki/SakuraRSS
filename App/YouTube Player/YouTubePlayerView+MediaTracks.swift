import SwiftUI
import WebKit
import Hanami

extension YouTubePlayerView {

    func refreshMediaTracks(retriesRemaining: Int = 6) {
        guard let webView else { return }
        webView.evaluateJavaScript(YouTubePlayerScripts.extractMediaTracks) { result, _ in
            let captions = Self.parseCaptionTracks(from: result)
            DispatchQueue.main.async {
                if !captions.isEmpty { self.captionTracks = captions }
                // The captions module can initialize a moment after playback
                // starts, so keep polling until it appears.
                if self.captionTracks.isEmpty && retriesRemaining > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.refreshMediaTracks(retriesRemaining: retriesRemaining - 1)
                    }
                }
            }
        }
    }

    /// Forces the original (non-dubbed) audio via the MSE player's
    /// `setAudioTrack()`. The track list can be empty right after playback
    /// starts, so retry until it resolves.
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
                    // "switched", "original", or "none" — resolved.
                    self.didForceOriginalAudio = true
                }
            }
        }
    }

    func selectCaptionTrack(code: String) {
        let encoded = Self.jsStringLiteral(code)
        webView?.evaluateJavaScript(
            YouTubePlayerScripts.setCaptionTrack(encodedCode: encoded)
        ) { [self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                refreshMediaTracks(retriesRemaining: 0)
            }
        }
    }

    private static func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }

    private static func parseCaptionTracks(from result: Any?) -> [YouTubeCaptionTrack] {
        guard let dictionary = result as? [String: Any],
              let array = dictionary["captions"] as? [[String: Any]] else {
            return []
        }
        return array.compactMap { entry in
            guard let code = entry["code"] as? String, !code.isEmpty,
                  let name = entry["name"] as? String else { return nil }
            return YouTubeCaptionTrack(
                code: code,
                name: name,
                isSelected: (entry["selected"] as? Bool) ?? false
            )
        }
    }
}
