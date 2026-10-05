import AppKit
import Hanami

/// Shows the unread count on the Dock icon when the unread badge setting is
/// on. The Dock needs no notification permission, unlike iOS's badge.
final class DockBadgeCoordinator {

    private let feedManager: FeedManager
    private var observer: ChangeObserver?
    private var defaultsObserver: NSObjectProtocol?
    private var pendingUpdate: DispatchWorkItem?

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        observer = ChangeObserver { [weak self] in
            guard let self else { return }
            _ = (self.feedManager.dataRevision, self.feedManager.readMaskRevision)
        } onChange: { [weak self] in
            self?.scheduleUpdate()
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleUpdate()
            }
        }
        update()
    }

    static var isEnabled: Bool {
        UserDefaults.standard.string(forKey: UnreadBadgeMode.storageKey) == UnreadBadgeMode.homeScreenOnly.rawValue
    }

    private func scheduleUpdate() {
        pendingUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.update() }
        pendingUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func update() {
        let count = Self.isEnabled ? feedManager.totalUnreadCount() : 0
        let label = count > 0 ? count.formatted() : nil
        if NSApp.dockTile.badgeLabel != label {
            NSApp.dockTile.badgeLabel = label
        }
    }
}
