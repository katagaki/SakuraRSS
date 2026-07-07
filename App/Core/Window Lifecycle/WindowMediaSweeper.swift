#if targetEnvironment(macCatalyst)
import AVFoundation
import UIKit
import WebKit

enum WindowMediaSweeper {

    static func stopMedia(in windowScene: UIWindowScene, capturedWindow: UIWindow?) {
        var windows = windowScene.windows
        if let capturedWindow, !windows.contains(capturedWindow) {
            windows.append(capturedWindow)
        }
        for window in windows {
            stopMedia(in: window)
        }
    }

    private static func stopMedia(in view: UIView) {
        if let webView = view as? WKWebView {
            webView.pauseAllMediaPlayback(completionHandler: nil)
        } else if let playerLayer = view.layer as? AVPlayerLayer {
            playerLayer.player?.pause()
        }
        for subview in view.subviews {
            stopMedia(in: subview)
        }
    }
}
#endif
