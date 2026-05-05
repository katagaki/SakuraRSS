import SwiftUI

struct DataSettingsView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var deviceStats: DeviceStorageStats?
    @State private var feedSizes: [(feed: Feed, bytes: Int64)] = []
    @State private var isLoadingStorage = true

    var body: some View {
        List {
            DataSettingsSection()
            StorageSettingsSection(deviceStats: deviceStats)
            CleanupSettingsSection()
            if isLoadingStorage || !feedSizes.isEmpty {
                FeedStorageSection(feedSizes: feedSizes, isLoading: isLoadingStorage)
            }
            PortabilitySection()
        }
        .listStyle(.insetGrouped)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Data", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadStorageStats()
        }
    }

    private func loadStorageStats() async {
        let database = feedManager.database
        let feedsByID = feedManager.feedsByID
        let computed = await Task.detached(priority: .utility) {
            let imageCacheBytes = database.imageCacheTableSize()
            let breakdown = sakuraStorageBreakdown(imageCacheTableBytes: imageCacheBytes)
            let device = DeviceStorageStats.current(breakdown: breakdown)
            let perFeedBytes = (try? database.storageSizeByFeed()) ?? [:]
            let entries = perFeedBytes
                .compactMap { (id, bytes) -> (Feed, Int64)? in
                    guard let feed = feedsByID[id] else { return nil }
                    return (feed, bytes)
                }
                .sorted { $0.1 > $1.1 }
            return (device, entries)
        }.value
        deviceStats = computed.0
        feedSizes = computed.1
        isLoadingStorage = false
    }
}
