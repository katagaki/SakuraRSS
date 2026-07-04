import SwiftUI
import Hanami

/// Presents the bookmark confirmation toast in a passthrough overlay window,
/// so it stays visible above sheets like the podcast and YouTube players.
@Observable
final class BookmarkToastManager {

    static let shared = BookmarkToastManager()

    private(set) var article: Article?
    @ObservationIgnored private var overlayWindow: BookmarkToastWindow?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    private static let visibleDuration: Duration = .seconds(5)
    private static let menuOpenGraceDuration: Duration = .seconds(20)

    private init() {}

    func show(article: Article, feedManager: FeedManager) {
        let isNewWindow = presentOverlayWindowIfNeeded(feedManager: feedManager)
        if isNewWindow {
            // A freshly attached window must render its empty state once,
            // or the toast's insertion transition doesn't animate.
            DispatchQueue.main.async {
                self.presentToast(article)
            }
        } else {
            presentToast(article)
        }
    }

    private func presentToast(_ article: Article) {
        withAnimation(.smooth.speed(2.0)) {
            self.article = article
        }
        scheduleDismiss(after: Self.visibleDuration)
    }

    /// Called when the toast is tapped, so the folder menu isn't yanked away
    /// mid-selection by the standard dismissal timer.
    func delayDismissal() {
        scheduleDismiss(after: Self.menuOpenGraceDuration)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        hideToast()
    }

    private func scheduleDismiss(after delay: Duration) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            hideToast()
        }
    }

    private func hideToast() {
        withAnimation(.smooth.speed(2.0)) {
            article = nil
        }
        scheduleWindowTeardown()
    }

    private func scheduleWindowTeardown() {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard article == nil else { return }
            overlayWindow?.isHidden = true
            overlayWindow = nil
        }
    }

    private func presentOverlayWindowIfNeeded(feedManager: FeedManager) -> Bool {
        guard let scene = activeWindowScene() else { return false }
        if let overlayWindow, overlayWindow.windowScene === scene {
            return false
        }
        overlayWindow?.isHidden = true
        let window = BookmarkToastWindow(windowScene: scene)
        let hostingController = UIHostingController(
            rootView: BookmarkToastOverlayView(feedManager: feedManager)
        )
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.windowLevel = .alert
        window.isHidden = false
        window.layoutIfNeeded()
        overlayWindow = window
        return true
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foregroundScenes = scenes.filter { $0.activationState == .foregroundActive }
        return foregroundScenes.first { scene in
            scene.windows.contains { $0.isKeyWindow }
        } ?? foregroundScenes.first
    }
}
