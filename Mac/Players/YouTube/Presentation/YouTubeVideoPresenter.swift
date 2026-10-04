import AppKit
import Hanami
import WebKit

/// Picture in Picture and fullscreen for YouTube on the Mac, as windows the
/// playing web view moves into. WebKit offers its own Picture in Picture only
/// to Safari, and its element fullscreen keeps the web view at its inline
/// size inside SwiftUI.
@MainActor
@Observable
final class YouTubeVideoPresenter {

    enum Mode {
        case pictureInPicture
        case fullscreen
    }

    static let shared = YouTubeVideoPresenter()

    private(set) var mode: Mode?
    var isPictureInPicture: Bool { mode == .pictureInPicture }
    var isDetached: Bool { mode != nil }

    @ObservationIgnored var pictureInPictureWindow: NSPanel?
    @ObservationIgnored var fullscreenWindow: YouTubeFullscreenWindow?
    @ObservationIgnored private weak var originalSuperview: NSView?
    @ObservationIgnored private var originalTranslatesAutoresizing = true
    @ObservationIgnored private var resizeObserver: NSObjectProtocol?

    func togglePictureInPicture(session: YouTubePlayerSession) {
        if mode == .pictureInPicture {
            exit(session: session, returningToContent: true)
        } else if mode == nil {
            present(.pictureInPicture, session: session)
        }
    }

    func toggleFullscreen(session: YouTubePlayerSession) {
        if mode == .fullscreen {
            fullscreenWindow?.toggleFullScreen(nil)
        } else {
            present(.fullscreen, session: session)
        }
    }

    func exit(session: YouTubePlayerSession, returningToContent: Bool) {
        guard mode != nil else { return }
        mode = nil
        pictureInPictureWindow?.orderOut(nil)
        fullscreenWindow?.orderOut(nil)
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
        guard let webView = session.webView else { return }
        YouTubePlaybackCommands.setVideoOnlyLayout(webView, size: nil)
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizing
        if let originalSuperview, originalSuperview.window != nil {
            webView.frame = originalSuperview.bounds
            webView.autoresizingMask = [.width, .height]
            originalSuperview.addSubview(webView)
        } else if returningToContent, let article = session.currentArticle {
            // The player page is gone; reopening it adopts this web view.
            NotificationCenter.default.post(
                name: .openArticleFromIntent,
                object: nil,
                userInfo: ["articleID": article.id]
            )
        }
        originalSuperview = nil
    }

    private func present(_ newMode: Mode, session: YouTubePlayerSession) {
        guard let webView = session.webView else { return }
        if mode == nil {
            originalSuperview = webView.superview
            originalTranslatesAutoresizing = webView.translatesAutoresizingMaskIntoConstraints
        }
        pictureInPictureWindow?.orderOut(nil)
        let window: NSWindow = switch newMode {
        case .pictureInPicture: preparedPictureInPictureWindow(session: session)
        case .fullscreen: preparedFullscreenWindow(session: session)
        }
        guard let container = window.contentView else { return }
        webView.removeFromSuperview()
        // Follows the window when it's resized, whatever SwiftUI set.
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView, positioned: .below, relativeTo: container.subviews.first)
        mode = newMode
        followSize(of: window, for: webView)
        switch newMode {
        case .pictureInPicture:
            window.orderFrontRegardless()
        case .fullscreen:
            window.makeKeyAndOrderFront(nil)
            window.toggleFullScreen(nil)
        }
    }

    private func followSize(of window: NSWindow, for webView: WKWebView) {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        YouTubePlaybackCommands.setVideoOnlyLayout(webView, size: window.contentView?.bounds.size)
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak webView, weak window] _ in
            MainActor.assumeIsolated {
                YouTubePlaybackCommands.setVideoOnlyLayout(webView, size: window?.contentView?.bounds.size)
            }
        }
    }
}
