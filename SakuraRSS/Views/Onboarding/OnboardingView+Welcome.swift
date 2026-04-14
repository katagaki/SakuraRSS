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
                    Text("Onboarding.Welcome.Title.\(appName)")
                        .font(.largeTitle.bold())
                }

                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "newspaper.fill",
                        title: String(localized: "Onboarding.Feature.Feeds"),
                        description: String(localized: "Onboarding.Feature.Feeds.Description")
                    )
                    featureRow(
                        icon: "rectangle.grid.2x2.fill",
                        title: String(localized: "Onboarding.Feature.ViewStyles"),
                        description: String(localized: "Onboarding.Feature.ViewStyles.Description")
                    )
                    featureRow(
                        icon: "headphones",
                        title: String(localized: "Onboarding.Feature.Podcasts"),
                        description: String(localized: "Onboarding.Feature.Podcasts.Description")
                    )
                    featureRow(
                        icon: "apple.intelligence",
                        title: String(localized: "Onboarding.Feature.Summaries"),
                        description: String(localized: "Onboarding.Feature.Summaries.Description")
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
        .alert("iCloudBackup.RestoreError", isPresented: $showRestoreError) {
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
                    Text("Onboarding.Restore.Title")
                        .font(.body.weight(.semibold))
                    Text("Onboarding.Restore.Description \(metadata.deviceName) \(metadata.date.formatted(date: .abbreviated, time: .shortened))")
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
                        Text("Onboarding.Restore.Restoring")
                    } else {
                        Text("Onboarding.Restore.Button")
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
