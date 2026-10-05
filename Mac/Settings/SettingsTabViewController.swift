import AppKit

/// Animates the window to each tab's size, keeping its top edge in place, as
/// Safari's settings do. `NSTabViewController` alone only snaps to it.
final class SettingsTabViewController: NSTabViewController {

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window, let pane = tabViewItem?.viewController else { return }
        resize(window, toFit: pane, animated: window.isVisible)
    }

    func resize(_ window: NSWindow, toFit pane: NSViewController, animated: Bool) {
        // Only the intrinsic size is reported, which the tab view ignores, so
        // it can't snap the window before this animates it.
        let size = pane.view.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        let currentContent = window.contentRect(forFrameRect: window.frame)
        let targetContent = NSRect(
            x: currentContent.minX,
            y: currentContent.maxY - size.height,
            width: size.width,
            height: size.height
        )
        window.setFrame(window.frameRect(forContentRect: targetContent), display: true, animate: animated)
    }
}
