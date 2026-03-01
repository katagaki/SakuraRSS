import SwiftUI
import BackgroundTasks

@main
struct SakuraRSSApp: App {

    @State private var feedManager = FeedManager()
    private let backgroundTaskID = "com.tsubuzaki.SakuraRSS.RefreshFeeds"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.defaultMinListRowHeight, 10.0)
                .environment(feedManager)
                .task {
                    await feedManager.refreshAllFeeds()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    feedManager.loadFromDatabase()
                }
        }
    }

    init() {
        registerBackgroundTask()
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }
        scheduleAppRefresh()
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        let refreshInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        let minutes = refreshInterval > 0 ? refreshInterval : 60
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let refreshTask = Task {
            let manager = FeedManager()
            await manager.refreshAllFeeds()
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }

        Task {
            _ = await refreshTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
