import Foundation
@preconcurrency import UserNotifications

extension FeedManager {

    // MARK: - Badge

    nonisolated func updateBadgeCount() {
        let mode = UserDefaults.standard.string(forKey: "Display.UnreadBadgeMode") ?? "none"
        let center = UNUserNotificationCenter.current()
        guard mode == "homeScreenAndHomeTab" || mode == "homeScreenOnly" else {
            Task { try? await center.setBadgeCount(0) }
            return
        }
        Task {
            let settings = await center.notificationSettings()
            guard settings.badgeSetting == .enabled else { return }
            let count = await self.totalUnreadCount()
            try? await center.setBadgeCount(count)
        }
    }

}
