import AppKit

/// Reload while idle and stop while the page refreshes, as Safari's button
/// does. The progress itself is drawn in the address bar.
final class RefreshToolbarButton: NSButton {

    var isRefreshing: (() -> Bool)? {
        didSet { observeRefreshing() }
    }
    private var refreshObserver: ChangeObserver?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 32, height: 28))
        bezelStyle = .toolbar
        imagePosition = .imageOnly
        update()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func observeRefreshing() {
        refreshObserver = ChangeObserver { [weak self] in
            _ = self?.isRefreshing?()
        } onChange: { [weak self] in
            self?.update()
        }
        update()
    }

    private func update() {
        let refreshing = isRefreshing?() ?? false
        let label = refreshing
            ? String(localized: "Refresh.Stop", table: "Home")
            : String(localized: "RefreshFeeds.ShortTitle", table: "AppIntents")
        image = NSImage(systemSymbolName: refreshing ? "xmark" : "arrow.clockwise", accessibilityDescription: label)
        toolTip = label
        action = refreshing ? #selector(RefreshActions.stopRefreshing(_:)) : #selector(RefreshActions.refreshFeeds(_:))
    }
}
