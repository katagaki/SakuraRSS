import CloudKit
import Hanami
import SwiftUI

// swiftlint:disable:next type_name
struct iCloudSyncSettingsRows: View {

    @AppStorage(CloudSyncEngine.enabledDefaultsKey) private var isSyncEnabled = false
    @State private var accountStatus: CKAccountStatus?
    @State private var isSyncing = false
    @State private var lastSyncedAt: Date?
    @State private var showSyncError = false

    private var syncToggle: Binding<Bool> {
        Binding(get: { isSyncEnabled }, set: { CloudSyncEngine.shared.setEnabled($0) })
    }

    var body: some View {
        Group {
            if accountStatus == .available {
                LabeledContent(SettingsText.data("iCloudSync.Title")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(SettingsText.data("iCloudSync.Enable"), isOn: syncToggle)
                        SettingsNote(text: SettingsText.data("iCloudSync.Footer"))
                    }
                }
                if isSyncEnabled {
                    LabeledContent(SettingsText.data("iCloudSync.LastSyncedLabel")) {
                        HStack(spacing: 10) {
                            lastSyncedText
                            Button(SettingsText.data("iCloudSync.SyncNow"), action: performSync)
                                .disabled(isSyncing)
                            if isSyncing {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                }
            } else if accountStatus != nil {
                LabeledContent(SettingsText.data("iCloudSync.Title")) {
                    SettingsNote(text: SettingsText.data("iCloudSync.Unavailable"))
                }
            }
        }
        .task {
            accountStatus = await CloudSyncEngine.shared.accountStatus()
            refreshLastSyncedAt()
        }
        .alert(SettingsText.data("iCloudSync.SyncError"), isPresented: $showSyncError) {
            Button("Shared.OK") {}
        }
    }

    @ViewBuilder
    private var lastSyncedText: some View {
        if let lastSyncedAt {
            Text(lastSyncedAt, style: .relative)
        } else {
            Text(SettingsText.data("iCloudSync.Never"))
        }
    }

    private func performSync() {
        isSyncing = true
        Task {
            do {
                try await CloudSyncEngine.shared.syncNow()
            } catch {
                showSyncError = true
            }
            refreshLastSyncedAt()
            isSyncing = false
        }
    }

    private func refreshLastSyncedAt() {
        lastSyncedAt = UserDefaults.standard.object(forKey: CloudSyncEngine.lastSyncedAtDefaultsKey) as? Date
    }
}
