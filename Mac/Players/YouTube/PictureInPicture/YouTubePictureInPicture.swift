import AppKit
import Hanami
import WebKit

/// Picture in Picture for YouTube on the Mac, as a floating panel the
/// playing web view moves into, since WebKit keeps its own to Safari.
@MainActor
@Observable
final class YouTubePictureInPicture {

    static let shared = YouTubePictureInPicture()

    private(set) var isActive = false

    @ObservationIgnored private var panel: YouTubePictureInPicturePanel?
    @ObservationIgnored private var contentView: YouTubePictureInPictureContentView?
    @ObservationIgnored private weak var inlineContainer: NSView?

    func toggle(session: YouTubePlayerSession) {
        if isActive {
            exit(session: session, returningToContent: true)
        } else {
            enter(session: session)
        }
    }

    func enter(session: YouTubePlayerSession) {
        guard !isActive, let webView = session.webView else { return }
        let (panel, contentView) = preparedPanel(session: session)
        inlineContainer = webView.superview
        contentView.hold(webView)
        YouTubePlaybackCommands.setPictureInPictureLayout(webView, isEnabled: true)
        panel.present(aspectRatio: session.videoAspectRatio)
        isActive = true
    }

    func exit(session: YouTubePlayerSession, returningToContent: Bool) {
        guard isActive else { return }
        isActive = false
        panel?.orderOut(nil)
        guard let webView = contentView?.releaseWebView() else { return }
        YouTubePlaybackCommands.setPictureInPictureLayout(webView, isEnabled: false)
        if let inlineContainer, inlineContainer.window != nil {
            webView.frame = inlineContainer.bounds
            webView.autoresizingMask = [.width, .height]
            inlineContainer.addSubview(webView)
        } else if returningToContent, let article = session.currentArticle {
            // The player page is gone; reopening it adopts this web view.
            NotificationCenter.default.post(
                name: .openArticleFromIntent,
                object: nil,
                userInfo: ["articleID": article.id]
            )
        }
        inlineContainer = nil
    }

    private func preparedPanel(
        session: YouTubePlayerSession
    ) -> (YouTubePictureInPicturePanel, YouTubePictureInPictureContentView) {
        if let panel, let contentView {
            return (panel, contentView)
        }
        let contentView = YouTubePictureInPictureContentView(controls: YouTubePictureInPictureControls(
            session: session,
            onDragChanged: { [weak self] in self?.panel?.continueDrag() },
            onDragEnded: { [weak self] in self?.panel?.endDrag() },
            onReturn: { [weak self] in self?.exit(session: session, returningToContent: true) },
            onClose: { [weak self] in
                session.pause()
                self?.exit(session: session, returningToContent: false)
            }
        ))
        let panel = YouTubePictureInPicturePanel(contentView: contentView)
        contentView.onWebViewTaken = { [weak self, weak session] in
            guard let self, self.isActive else { return }
            self.isActive = false
            self.panel?.orderOut(nil)
            self.inlineContainer = nil
            YouTubePlaybackCommands.setPictureInPictureLayout(session?.webView, isEnabled: false)
        }
        self.panel = panel
        self.contentView = contentView
        return (panel, contentView)
    }
}
