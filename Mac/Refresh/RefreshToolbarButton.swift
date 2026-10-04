import AppKit
import Hanami

/// Refreshes when idle, and while a refresh runs shows its progress and stops
/// it when clicked.
final class RefreshToolbarButton: NSView {

    private let feedManager: FeedManager
    private let button = NSButton()
    private let progressIndicator = NSProgressIndicator()
    private var refreshObserver: ChangeObserver?

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        super.init(frame: NSRect(x: 0, y: 0, width: 32, height: 28))
        button.bezelStyle = .toolbar
        button.imagePosition = .imageOnly
        button.isBordered = true
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isIndeterminate = false
        progressIndicator.isHidden = true
        for view in [button, progressIndicator] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        refreshObserver = ChangeObserver { [weak self] in
            guard let self else { return }
            _ = (self.feedManager.isLoading, self.feedManager.refreshCompleted, self.feedManager.refreshTotal)
        } onChange: { [weak self] in
            self?.update()
        }
        update()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func update() {
        let isRefreshing = feedManager.isLoading
        progressIndicator.isHidden = !isRefreshing
        button.image = isRefreshing ? nil : NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: String(localized: "RefreshFeeds.ShortTitle", table: "AppIntents")
        )
        button.action = isRefreshing ? #selector(RefreshActions.stopRefreshing(_:))
            : #selector(RefreshActions.refreshFeeds(_:))
        if isRefreshing {
            let total = max(feedManager.refreshTotal, 1)
            progressIndicator.maxValue = Double(total)
            progressIndicator.doubleValue = Double(feedManager.refreshCompleted)
            button.toolTip = String(
                localized: "Home.Refreshing \(Int64(feedManager.refreshCompleted)) \(Int64(total))",
                table: "Home"
            ) + "\n" + String(localized: "Refresh.Stop", table: "Home")
        } else {
            button.toolTip = String(localized: "RefreshFeeds.ShortTitle", table: "AppIntents")
        }
    }
}
