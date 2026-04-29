import SwiftUI

// swiftlint:disable:next type_name
struct iCloudBackupView: View {

    @AppStorage("iCloudBackup.Interval")
    private var backupIntervalRaw: Int = iCloudBackupManager.BackupInterval.everyNight.rawValue
    @State private var isBackingUp = false
    @State private var lastBackupDate: Date?
    @State private var showBackupError = false
    @State private var showBackupSuccess = false
    @State private var iCloudAvailable = true

    private var backupInterval: Binding<iCloudBackupManager.BackupInterval> {
        Binding(
            get: {
                iCloudBackupManager.BackupInterval(rawValue: backupIntervalRaw) ?? .everyNight
            },
            set: { newValue in
                backupIntervalRaw = newValue.rawValue
            }
        )
    }

    var body: some View {
        List {
            if iCloudAvailable {
                Section {
                    HStack {
                        Text(String(localized: "iCloudBackup.LastBackupLabel", table: "DataManagement"))
                        Spacer()
                        if let lastBackupDate {
                            Text(lastBackupDate, style: .relative)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(localized: "iCloudBackup.Never", table: "DataManagement"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        performBackup()
                    } label: {
                        HStack {
                            Text(String(localized: "iCloudBackup.BackupNow", table: "DataManagement"))
                            Spacer()
                            if isBackingUp {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isBackingUp)
                } footer: {
                    Text(String(localized: "iCloudBackup.Footer", table: "DataManagement"))
                }

                Section {
                    Picker(
                        String(localized: "iCloudBackup.AutoBackup", table: "DataManagement"),
                        selection: backupInterval
                    ) {
                        Text(String(localized: "iCloudBackup.Interval.EveryNight", table: "DataManagement"))
                            .tag(iCloudBackupManager.BackupInterval.everyNight)
                        Text(String(localized: "iCloudBackup.Interval.Every12Hours", table: "DataManagement"))
                            .tag(iCloudBackupManager.BackupInterval.every12Hours)
                        Text(String(localized: "iCloudBackup.Interval.Every6Hours", table: "DataManagement"))
                            .tag(iCloudBackupManager.BackupInterval.every6Hours)
                        Text(String(localized: "iCloudBackup.Interval.Off", table: "DataManagement"))
                            .tag(iCloudBackupManager.BackupInterval.off)
                    }
                }
            } else {
                Section {
                    Text(String(localized: "iCloudBackup.Unavailable", table: "DataManagement"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "iCloudBackup.Title", table: "DataManagement"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .task {
            iCloudAvailable = iCloudBackupManager.shared.isICloudAvailable()
            lastBackupDate = iCloudBackupManager.shared.lastBackupDate
        }
        .alert(
            String(localized: "iCloudBackup.BackupSuccess", table: "DataManagement"),
            isPresented: $showBackupSuccess
        ) {
            Button("Shared.OK") {}
        }
        .alert(
            String(localized: "iCloudBackup.BackupError", table: "DataManagement"),
            isPresented: $showBackupError
        ) {
            Button("Shared.OK") {}
        }
    }

    private func performBackup() {
        isBackingUp = true
        Task {
            do {
                try await iCloudBackupManager.shared.backupNow()
                lastBackupDate = iCloudBackupManager.shared.lastBackupDate
                showBackupSuccess = true
            } catch {
                showBackupError = true
            }
            isBackingUp = false
        }
    }
}
