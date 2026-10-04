import AppKit
import Hanami

final class BrowserWindowController: NSWindowController, NSWindowDelegate {

    static let tabbingIdentifier = "SakuraBrowser"

    let feedManager: FeedManager
    let splitViewController: BrowserSplitViewController
    let activity = BrowserPageActivity()
    let addressBarController: AddressBarController
    let toolbarController: BrowserToolbarController
    private(set) var history: BrowserHistory
    var onClose: ((BrowserWindowController) -> Void)?
    private var titleObserver: ChangeObserver?
    private var displayStyleMenuPopulator: MenuPopulator?

    init(feedManager: FeedManager, history: BrowserHistory) {
        self.feedManager = feedManager
        self.history = history
        splitViewController = BrowserSplitViewController(feedManager: feedManager, activity: activity)
        addressBarController = AddressBarController(feedManager: feedManager, activity: activity)
        let refreshButton = RefreshToolbarButton()
        toolbarController = BrowserToolbarController(
            addressField: addressBarController.containerView,
            refreshButton: refreshButton
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = splitViewController
        window.setContentSize(NSSize(width: 1100, height: 720))
        window.contentMinSize = NSSize(width: 880, height: 480)
        window.tabbingMode = .automatic
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.toolbarStyle = .unified
        window.titleVisibility = .hidden
        window.toolbar = toolbarController.toolbar
        window.identifier = BrowserWindowRestoration.windowIdentifier
        window.restorationClass = BrowserWindowRestoration.self
        super.init(window: window)
        window.delegate = self
        // Without one, AppKit focuses the first key view it finds when the
        // window becomes key, ringing the first button on Today.
        window.initialFirstResponder = splitViewController.sidebarViewController.outlineView
        refreshButton.isRefreshing = { [weak self] in self?.isCurrentPageRefreshing ?? false }
        connectCallbacks()
        showCurrentLocation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func connectCallbacks() {
        splitViewController.sidebarViewController.onSelectLocation = { [weak self] location in
            self?.navigate(to: location)
        }
        let populator = MenuPopulator { [weak self] menu in
            self?.populateDisplayStyleMenu(menu)
        }
        displayStyleMenuPopulator = populator
        toolbarController.displayStyleMenuDelegate = populator
        splitViewController.onReaderArticleChange = { [weak self] article in
            self?.updateHandoff(for: article)
        }
        toolbarController.onShowEpisode = { [weak self] articleID in
            self?.navigate(to: .article(articleID))
        }
        addressBarController.onCommit = { [weak self] kind in
            self?.commitAddress(kind)
        }
        splitViewController.onOpenLocation = { [weak self] location in
            self?.navigate(to: location)
        }
        splitViewController.onOpenLocationInNewTab = { [weak self] location in
            guard let window = self?.window, let registry = (NSApp.delegate as? AppDelegate)?.registry else { return }
            registry.openTab(beside: window, history: BrowserHistory(current: location))
        }
        titleObserver = ChangeObserver { [weak self] in
            guard let self else { return }
            _ = self.history.current.title(in: self.feedManager)
        } onChange: { [weak self] in
            self?.updateTitle()
        }
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
        toolbarController.updateDisplayStyleItem(context: displayStyleContext)
        updateHandoffForCurrentLocation()
        window?.toolbar?.validateVisibleItems()
        window?.invalidateRestorableState()
    }

    private func updateTitle() {
        window?.title = history.current.title(in: feedManager)
        addressBarController.display(history.current)
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        history.encode(with: state)
    }

    func windowWillClose(_ notification: Notification) {
        titleObserver?.cancel()
        onClose?(self)
    }
}
