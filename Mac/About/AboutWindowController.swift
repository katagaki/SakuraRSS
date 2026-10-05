import AppKit
import SwiftUI

final class AboutWindowController: NSWindowController {

    init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
        window.styleMask = [.titled, .closable]
        window.title = String(format: String(localized: "Menu.About", table: "Mac"), MainMenuBuilder.applicationName)
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
