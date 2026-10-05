#if DEBUG
import AppKit
import Hanami

/// Sets up the frontmost window for an App Store capture. `-DebugShowLocation feed:12`
/// navigates it, `-DebugCollapseSidebar YES` hides its sidebar, `-DebugSelectContent 345`
/// opens that content in the reader beside the list, and `-DebugWindowSize 1100x690` gives
/// the window exactly that frame, in points, on the sharpest screen. The window's number is
/// written to `-DebugWindowNumberPath` once it's ready, for `screencapture -l`.
enum DebugCaptureScene {

    static func perform(with registry: BrowserWindowRegistry) {
        let defaults = UserDefaults.standard
        guard let controller = registry.controllers.last, let window = controller.window else { return }
        if let token = defaults.string(forKey: "DebugShowLocation"),
           let location = BrowserLocation(persistenceToken: token) {
            controller.navigate(to: location)
        }
        if defaults.bool(forKey: "DebugCollapseSidebar") {
            controller.splitViewController.splitViewItems.first?.isCollapsed = true
        }
        if let size = defaults.string(forKey: "DebugWindowSize").flatMap(parseSize) {
            place(window, size: size)
        }
        if let articleID = defaults.string(forKey: "DebugSelectContent").flatMap({ Int64($0) }) {
            controller.splitViewController.detailViewController.contentSplitViewController
                .contentListViewController.selectContent(articleID)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        if let path = defaults.string(forKey: "DebugWindowNumberPath") {
            try? String(window.windowNumber).write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    private static func parseSize(_ text: String) -> NSSize? {
        let parts = text.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return NSSize(width: parts[0], height: parts[1])
    }

    /// Centered on the screen with the highest scale, so the capture has the most pixels.
    private static func place(_ window: NSWindow, size: NSSize) {
        guard let screen = NSScreen.screens.max(by: { $0.backingScaleFactor < $1.backingScaleFactor }) else {
            return
        }
        let visible = screen.visibleFrame
        window.setFrame(NSRect(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        ), display: true)
    }
}

private extension ContentListViewController {

    func selectContent(_ articleID: Int64) {
        guard let row = articles.firstIndex(where: { $0.id == articleID }) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }
}
#endif
