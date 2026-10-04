import AppKit
import Hanami
import SwiftUI

extension YouTubeVideoPresenter {

    func preparedPictureInPictureWindow(session: YouTubePlayerSession) -> NSPanel {
        let panel = pictureInPictureWindow ?? makePictureInPictureWindow(session: session)
        pictureInPictureWindow = panel
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
        return panel
    }

    func preparedFullscreenWindow(session: YouTubePlayerSession) -> YouTubeFullscreenWindow {
        let window = fullscreenWindow ?? makeFullscreenWindow(session: session)
        fullscreenWindow = window
        if let screenFrame = (NSApp.keyWindow?.screen ?? NSScreen.main)?.frame {
            window.setFrame(screenFrame.insetBy(dx: screenFrame.width / 6, dy: screenFrame.height / 6), display: false)
        }
        return window
    }

    private func makePictureInPictureWindow(session: YouTubePlayerSession) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 236),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hideTitleBar(of: panel)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 240, height: 135)
        panel.contentView = container(with: YouTubeVideoWindowControls(
            session: session,
            mode: .pictureInPicture,
            onReturn: { [weak self] in self?.exit(session: session, returningToContent: true) },
            onClose: { [weak self] in
                session.pause()
                self?.exit(session: session, returningToContent: false)
            }
        ))
        return panel
    }

    private func makeFullscreenWindow(session: YouTubePlayerSession) -> YouTubeFullscreenWindow {
        let window = YouTubeFullscreenWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        hideTitleBar(of: window)
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentView = container(with: YouTubeVideoWindowControls(
            session: session,
            mode: .fullscreen,
            onReturn: { [weak window] in window?.toggleFullScreen(nil) },
            onClose: { [weak window] in window?.toggleFullScreen(nil) }
        ))
        NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.exit(session: session, returningToContent: true)
            }
        }
        return window
    }

    private func hideTitleBar(of window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
    }

    private func container(with controls: YouTubeVideoWindowControls) -> NSView {
        let container = NSView()
        let controlsView = NSHostingView(rootView: controls)
        controlsView.autoresizingMask = [.width, .height]
        container.addSubview(controlsView)
        return container
    }
}

/// Esc leaves fullscreen, as it does for video elsewhere on the Mac.
final class YouTubeFullscreenWindow: NSWindow {

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        if styleMask.contains(.fullScreen) {
            toggleFullScreen(nil)
        }
    }
}
