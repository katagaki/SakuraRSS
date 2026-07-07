import CloudKit
import SwiftUI
import Hanami

// swiftlint:disable:next type_name
struct iCloudSyncView: View {

    @AppStorage(CloudSyncEngine.enabledDefaultsKey) private var isSyncEnabled = false
    @State private var isSyncing = false
    @State private var lastSyncedAt: Date?
    @State private var accountStatus: CKAccountStatus = .available
    @State private var showSyncError = false

    private var syncToggle: Binding<Bool> {
        Binding(
            get: { isSyncEnabled },
            set: { newValue in
                CloudSyncEngine.shared.setEnabled(newValue)
            }
        )
    }

    var body: some View {
        List {
            if accountStatus == .available {
                Section {
                    Toggle(
                        String(localized: "iCloudSync.Enable", table: "DataManagement"),
                        isOn: syncToggle
                    )
                } footer: {
                    Text(String(localized: "iCloudSync.Footer", table: "DataManagement"))
                }

                if isSyncEnabled {
                    Section {
                        HStack {
                            Text(String(localized: "iCloudSync.LastSyncedLabel", table: "DataManagement"))
                            Spacer()
                            if let lastSyncedAt {
                                Text(lastSyncedAt, style: .relative)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(String(localized: "iCloudSync.Never", table: "DataManagement"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            performSync()
                        } label: {
                            HStack {
                                Text(String(localized: "iCloudSync.SyncNow", table: "DataManagement"))
                                Spacer()
                                if isSyncing {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSyncing)
                    }
                }
            } else {
                Section {
                    Text(String(localized: "iCloudSync.Unavailable", table: "DataManagement"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "iCloudSync.Title", table: "DataManagement"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .task {
            accountStatus = await CloudSyncEngine.shared.accountStatus()
            refreshLastSyncedAt()
        }
        .alert(
            String(localized: "iCloudSync.SyncError", table: "DataManagement"),
            isPresented: $showSyncError
        ) {
            Button("Shared.OK") {}
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
        lastSyncedAt = UserDefaults.standard
            .object(forKey: CloudSyncEngine.lastSyncedAtDefaultsKey) as? Date
    }
}
