import Foundation
@preconcurrency import UserNotifications

extension FeedManager {

    // MARK: - Badge

    static let badgeUpdateDebounceInterval: DispatchTimeInterval = .milliseconds(1000)

    /// Debounced — coalesces rapid badge requests (e.g. mark-read-on-scroll flushes)
    /// into one update so MainActor work doesn't pile up during scrolling.
    nonisolated func updateBadgeCount() {
        Task { @MainActor [weak self] in
            self?.scheduleBadgeUpdate()
        }
    }

    private func scheduleBadgeUpdate() {
        badgeUpdateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performBadgeUpdate()
        }
        badgeUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.badgeUpdateDebounceInterval,
            execute: workItem
        )
    }

    private func performBadgeUpdate() {
        let mode = UserDefaults.standard.string(forKey: "Display.UnreadBadgeMode") ?? "none"
        let center = UNUserNotificationCenter.current()
        guard mode == "homeScreenAndHomeTab" || mode == "homeScreenOnly" else {
            Task { try? await center.setBadgeCount(0) }
            return
        }
        let count = totalUnreadCount()
        Task {
            let settings = await center.notificationSettings()
            guard settings.badgeSetting == .enabled else { return }
            try? await center.setBadgeCount(count)
        }
    }

}
