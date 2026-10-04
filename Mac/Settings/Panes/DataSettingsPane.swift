import Hanami
import SwiftUI

struct DataSettingsPane: View {

    let feedManager: FeedManager
    @State private var deviceStats: DeviceStorageStats?
    @State private var presentedPage: DataSettingsPage?

    var body: some View {
        SettingsForm {
            Group {
                LabeledContent("iCloud") {
                    HStack {
                        Button(SettingsText.data("iCloudSync.Title") + "…") { presentedPage = .iCloudSync }
                        Button(SettingsText.data("iCloudBackup.Title") + "…") { presentedPage = .iCloudBackup }
                    }
                }
            }
            SettingsGroupSpacer()
            Group {
                LabeledContent(SettingsText.settings("Section.Storage")) {
                    StorageBarSection(deviceStats: deviceStats)
                        .frame(width: 360)
                }
                CleanupSettingsSection()
            }
            SettingsGroupSpacer()
            Group {
                PortabilitySection()
                LabeledContent(SettingsText.settings("Section.Logs")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(SettingsText.settings("Section.Logs") + "…") { presentedPage = .logs }
                        SettingsNote(text: SettingsText.data("Logs.Footer"))
                    }
                }
            }
        }
        .environment(feedManager)
        .sheet(item: $presentedPage) { page in
            DataSettingsPageSheet(page: page)
                .environment(feedManager)
        }
        .task {
            let database = feedManager.database
            deviceStats = await Task.detached(priority: .utility) {
                let breakdown = sakuraStorageBreakdown(imageCacheTableBytes: database.imageCacheTableSize())
                return DeviceStorageStats.current(breakdown: breakdown)
            }.value
        }
    }
}

enum DataSettingsPage: String, Identifiable {
    case iCloudSync, iCloudBackup, logs

    var id: String { rawValue }
}

/// One of iOS's data pages, which link from its list, shown as a sheet.
private struct DataSettingsPageSheet: View {

    let page: DataSettingsPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch page {
                case .iCloudSync: iCloudSyncView()
                case .iCloudBackup: iCloudBackupView()
                case .logs: LogsView()
                }
            }
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Shared.Done")) { dismiss() }
                }
            }
        }
        .frame(width: 560, height: 520)
    }
}
