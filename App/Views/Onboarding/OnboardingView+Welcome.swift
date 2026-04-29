import SwiftUI

extension OnboardingView {

    var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(.sakuraIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 80)
                    Text(String(localized: "Welcome.Title.\(appName)", table: "Onboarding"))
                        .font(.largeTitle.bold())
                }

                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "newspaper.fill",
                        title: String(localized: "Feature.Feeds", table: "Onboarding"),
                        description: String(localized: "Feature.Feeds.Description", table: "Onboarding")
                    )
                    featureRow(
                        icon: "rectangle.grid.2x2.fill",
                        title: String(localized: "Feature.ViewStyles", table: "Onboarding"),
                        description: String(localized: "Feature.ViewStyles.Description", table: "Onboarding")
                    )
                    featureRow(
                        icon: "headphones",
                        title: String(localized: "Feature.Podcasts", table: "Onboarding"),
                        description: String(localized: "Feature.Podcasts.Description", table: "Onboarding")
                    )
                    featureRow(
                        icon: "apple.intelligence",
                        title: String(localized: "Feature.Summaries", table: "Onboarding"),
                        description: String(localized: "Feature.Summaries.Description", table: "Onboarding")
                    )
                }

                if let backupMetadata {
                    restoreSection(metadata: backupMetadata)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            continueButton { advanceStep() }
                .padding(.bottom, isIPad ? 20 : 0)
        }
        .task {
            backupMetadata = await iCloudBackupManager.shared.backupMetadata()
        }
        .alert(
            String(localized: "iCloudBackup.RestoreError", table: "DataManagement"),
            isPresented: $showRestoreError
        ) {
            Button("Shared.OK") {}
        }
    }

    private func restoreSection(metadata: iCloudBackupManager.BackupMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "icloud.fill")
                    .font(.title)
                    .foregroundStyle(.accent)
                    .frame(width: 36, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Restore.Title", table: "Onboarding"))
                        .font(.body.weight(.semibold))
                    // swiftlint:disable:next line_length
                    Text(String(localized: "Restore.Description \(metadata.deviceName) \(metadata.date.formatted(date: .abbreviated, time: .shortened))", table: "Onboarding"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                performRestore()
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .padding(.trailing, 4)
                        Text(String(localized: "Restore.Restoring", table: "Onboarding"))
                    } else {
                        Text(String(localized: "Restore.Button", table: "Onboarding"))
                    }
                }
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .disabled(isRestoring)
        }
    }

    private func performRestore() {
        isRestoring = true
        Task {
            do {
                try await iCloudBackupManager.shared.restore()
                feedManager.loadFromDatabase()
                UserDefaults.standard.set(true, forKey: "Onboarding.Completed")
                onComplete()
            } catch {
                showRestoreError = true
            }
            isRestoring = false
        }
    }
}
