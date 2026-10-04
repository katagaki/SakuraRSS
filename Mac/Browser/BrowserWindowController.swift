import AppKit
import Hanami

final class BrowserWindowController: NSWindowController, NSWindowDelegate {

    static let tabbingIdentifier = "SakuraBrowser"

    let feedManager: FeedManager
    let splitViewController: BrowserSplitViewController
    private(set) var history: BrowserHistory
    var onClose: ((BrowserWindowController) -> Void)?
    private var titleObserver: ChangeObserver?

    init(feedManager: FeedManager, history: BrowserHistory) {
        self.feedManager = feedManager
        self.history = history
        splitViewController = BrowserSplitViewController(feedManager: feedManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = splitViewController
        window.setContentSize(NSSize(width: 1100, height: 720))
        window.minSize = NSSize(width: 720, height: 420)
        window.tabbingMode = .automatic
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.toolbarStyle = .unified
        super.init(window: window)
        window.delegate = self
        splitViewController.sidebarViewController.onSelectLocation = { [weak self] location in
            self?.navigate(to: location)
        }
        titleObserver = ChangeObserver { [weak self] in
            guard let self else { return }
            _ = self.history.current.title(in: self.feedManager)
        } onChange: { [weak self] in
            self?.updateTitle()
        }
        showCurrentLocation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func navigate(to location: BrowserLocation) {
        history.navigate(to: location)
        showCurrentLocation()
    }

    func updateHistory(_ change: (inout BrowserHistory) -> Void) {
        change(&history)
        showCurrentLocation()
    }

    private func showCurrentLocation() {
        splitViewController.show(history.current)
        updateTitle()
    }

    private func updateTitle() {
        window?.title = history.current.title(in: feedManager)
    }

    func windowWillClose(_ notification: Notification) {
        titleObserver?.cancel()
        onClose?(self)
    }
}
