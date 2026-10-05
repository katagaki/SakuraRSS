import Hanami
import SwiftUI

// swiftlint:disable:next type_name
struct iCloudBackupSettingsRows: View {

    private typealias Interval = iCloudBackupManager.BackupInterval

    @AppStorage("iCloudBackup.Interval") private var backupInterval: Interval = .everyNight
    @State private var isICloudAvailable = true
    @State private var isBackingUp = false
    @State private var lastBackupDate: Date?
    @State private var showBackupError = false
    @State private var showBackupSuccess = false

    var body: some View {
        Group {
            if isICloudAvailable {
                SettingsPicker(SettingsText.data("iCloudBackup.AutoBackup"), selection: $backupInterval) {
                    Text(SettingsText.data("iCloudBackup.Interval.EveryNight")).tag(Interval.everyNight)
                    Text(SettingsText.data("iCloudBackup.Interval.Every12Hours")).tag(Interval.every12Hours)
                    Text(SettingsText.data("iCloudBackup.Interval.Every6Hours")).tag(Interval.every6Hours)
                    Divider()
                    Text(SettingsText.data("iCloudBackup.Interval.Off")).tag(Interval.off)
                }
                LabeledContent(SettingsText.data("iCloudBackup.LastBackupLabel")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            lastBackupText
                            Button(SettingsText.data("iCloudBackup.BackupNow"), action: performBackup)
                                .disabled(isBackingUp)
                            if isBackingUp {
                                ProgressView().controlSize(.small)
                            }
                        }
                        SettingsNote(text: SettingsText.data("iCloudBackup.Footer"))
                    }
                }
            } else {
                LabeledContent(SettingsText.data("iCloudBackup.Title")) {
                    SettingsNote(text: SettingsText.data("iCloudBackup.Unavailable"))
                }
            }
        }
        .task {
            isICloudAvailable = iCloudBackupManager.shared.isICloudAvailable()
            lastBackupDate = iCloudBackupManager.shared.lastBackupDate
        }
        .alert(SettingsText.data("iCloudBackup.BackupSuccess"), isPresented: $showBackupSuccess) {
            Button("Shared.OK") {}
        }
        .alert(SettingsText.data("iCloudBackup.BackupError"), isPresented: $showBackupError) {
            Button("Shared.OK") {}
        }
    }

    @ViewBuilder
    private var lastBackupText: some View {
        if let lastBackupDate {
            Text(lastBackupDate, style: .relative)
        } else {
            Text(SettingsText.data("iCloudBackup.Never"))
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
