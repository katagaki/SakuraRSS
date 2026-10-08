import Hanami
import SwiftUI

/// The Mac's first-launch welcome: what Sakura does, and a way to restore an
/// iCloud backup made on another device, as iOS's first onboarding step offers.
struct WelcomeView: View {

    let feedManager: FeedManager
    let onDone: () -> Void
    @State private var backupMetadata: iCloudBackupManager.BackupMetadata?
    @State private var isRestoring = false
    @State private var showsRestoreError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Image(.sakuraIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.tertiary)
                Text(String(localized: "Welcome.Title.\(MainMenuBuilder.applicationName)", table: "Onboarding"))
                    .font(.largeTitle.bold())
            }
            VStack(alignment: .leading, spacing: 18) {
                WelcomeFeatureRow(symbolName: "newspaper.fill", key: "Feature.Feeds")
                WelcomeFeatureRow(symbolName: "rectangle.grid.2x2.fill", key: "Feature.ViewStyles")
                WelcomeFeatureRow(symbolName: "headphones", key: "Feature.Podcasts")
                WelcomeFeatureRow(symbolName: "apple.intelligence", key: "Feature.Summaries")
            }
            if let backupMetadata {
                Divider()
                WelcomeRestoreRow(metadata: backupMetadata)
            }
            HStack {
                Spacer()
                if backupMetadata != nil {
                    Button(action: restore) {
                        if isRestoring {
                            Text(String(localized: "Restore.Restoring", table: "Onboarding"))
                        } else {
                            Text(String(localized: "Restore.Button", table: "Onboarding"))
                        }
                    }
                    .disabled(isRestoring)
                }
                Button(String(localized: "Continue", table: "Onboarding"), action: finish)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isRestoring)
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 520)
        .task {
            backupMetadata = await iCloudBackupManager.shared.backupMetadata()
        }
        .alert(
            String(localized: "iCloudBackup.RestoreError", table: "DataManagement"),
            isPresented: $showsRestoreError
        ) {
            Button("Shared.OK") {}
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            do {
                try await iCloudBackupManager.shared.restore()
                feedManager.loadFromDatabase()
                TodayShortcutPreferences.shared.reload()
                finish()
            } catch {
                showsRestoreError = true
            }
            isRestoring = false
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: WelcomeView.completedKey)
        onDone()
    }

    /// iOS's key, which people updating from the Catalyst app already have set.
    static let completedKey = "Onboarding.Completed"
}
