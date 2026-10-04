import AppKit
import Hanami
import SwiftUI
import WebKit

/// Picture in Picture for YouTube on the Mac, as a floating window the
/// playing web view moves into. WebKit offers its own only to Safari.
@MainActor
@Observable
final class YouTubePictureInPicture {

    static let shared = YouTubePictureInPicture()

    private(set) var isActive = false
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private weak var originalSuperview: NSView?
    @ObservationIgnored private var originalTranslatesAutoresizing = true

    func toggle(session: YouTubePlayerSession) {
        if isActive {
            exit(session: session, returningToContent: true)
        } else {
            enter(session: session)
        }
    }

    func enter(session: YouTubePlayerSession) {
        guard !isActive, let webView = session.webView else { return }
        originalSuperview = webView.superview
        originalTranslatesAutoresizing = webView.translatesAutoresizingMaskIntoConstraints
        let panel = panel ?? makePanel(session: session)
        self.panel = panel
        let aspectRatio = max(session.videoAspectRatio, 0.5)
        panel.contentAspectRatio = NSSize(width: aspectRatio, height: 1)
        let width: CGFloat = 420
        panel.setContentSize(NSSize(width: width, height: width / aspectRatio))
        if let visibleFrame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: visibleFrame.maxX - panel.frame.width - 20,
                y: visibleFrame.minY + 20
            ))
        }
        webView.removeFromSuperview()
        if let container = panel.contentView {
            // Follows the window when it's resized, whatever SwiftUI set.
            webView.translatesAutoresizingMaskIntoConstraints = true
            webView.frame = container.bounds
            webView.autoresizingMask = [.width, .height]
            container.addSubview(webView, positioned: .below, relativeTo: container.subviews.first)
        }
        isActive = true
        panel.orderFrontRegardless()
    }

    func exit(session: YouTubePlayerSession, returningToContent: Bool) {
        guard isActive else { return }
        isActive = false
        panel?.orderOut(nil)
        guard let webView = session.webView else { return }
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

    private func makePanel(session: YouTubePlayerSession) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 236),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .black
        panel.minSize = NSSize(width: 240, height: 135)
        let container = NSView()
        let controls = NSHostingView(rootView: YouTubePictureInPictureControls(
            session: session,
            onReturn: { [weak self] in self?.exit(session: session, returningToContent: true) },
            onClose: { [weak self] in
                session.pause()
                self?.exit(session: session, returningToContent: false)
            }
        ))
        controls.autoresizingMask = [.width, .height]
        container.addSubview(controls)
        panel.contentView = container
        controls.frame = container.bounds
        return panel
    }
}
