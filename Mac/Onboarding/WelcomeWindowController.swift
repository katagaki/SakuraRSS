import AppKit
import Hanami
import SwiftUI

/// The welcome in a window of its own rather than a sheet: a sheet on a tab
/// that isn't selected stays hidden until that tab is, and comes back into
/// view after the user thought it was gone. However the window closes, the
/// welcome counts as seen.
final class WelcomeWindowController: NSWindowController, NSWindowDelegate {

    var onClose: (() -> Void)?

    init(feedManager: FeedManager) {
        let hostingController = NSHostingController(rootView: AnyView(EmptyView()))
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.title = String(localized: "Welcome.Title.\(MainMenuBuilder.applicationName)", table: "Onboarding")
        super.init(window: window)
        window.delegate = self
        hostingController.rootView = AnyView(WelcomeView(feedManager: feedManager) { [weak self] in
            self?.close()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    static var hasBeenSeen: Bool {
        UserDefaults.standard.bool(forKey: WelcomeView.completedKey)
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: WelcomeView.completedKey)
        onClose?()
    }
}
