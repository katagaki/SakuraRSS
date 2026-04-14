import SwiftUI

// swiftlint:disable:next type_name
struct iCloudBackupView: View {

    @AppStorage("iCloudBackup.Interval") private var backupIntervalRaw: Int = iCloudBackupManager.BackupInterval.everyNight.rawValue
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
                        Text("iCloudBackup.LastBackupLabel")
                        Spacer()
                        if let lastBackupDate {
                            Text(lastBackupDate, style: .relative)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("iCloudBackup.Never")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        performBackup()
                    } label: {
                        HStack {
                            Text("iCloudBackup.BackupNow")
                            Spacer()
                            if isBackingUp {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isBackingUp)
                } footer: {
                    Text("iCloudBackup.Footer")
                }

                Section {
                    Picker("iCloudBackup.AutoBackup", selection: backupInterval) {
                        Text("iCloudBackup.Interval.EveryNight")
                            .tag(iCloudBackupManager.BackupInterval.everyNight)
                        Text("iCloudBackup.Interval.Every12Hours")
                            .tag(iCloudBackupManager.BackupInterval.every12Hours)
                        Text("iCloudBackup.Interval.Every6Hours")
                            .tag(iCloudBackupManager.BackupInterval.every6Hours)
                        Text("iCloudBackup.Interval.Off")
                            .tag(iCloudBackupManager.BackupInterval.off)
                    }
                }
            } else {
                Section {
                    Text("iCloudBackup.Unavailable")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("iCloudBackup.Title")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .task {
            iCloudAvailable = iCloudBackupManager.shared.isICloudAvailable()
            lastBackupDate = iCloudBackupManager.shared.lastBackupDate
        }
        .alert("iCloudBackup.BackupSuccess", isPresented: $showBackupSuccess) {
            Button("Shared.OK") {}
        }
        .alert("iCloudBackup.BackupError", isPresented: $showBackupError) {
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
