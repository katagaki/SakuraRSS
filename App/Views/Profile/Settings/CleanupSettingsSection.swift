import SwiftUI

struct CleanupSettingsSection: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Cleanup.Automatic.Enabled") private var automaticCleanupEnabled: Bool = false
    @AppStorage("Cleanup.Automatic.Cutoff") private var automaticCleanupCutoff: CleanupCutoff = .last30Days
    @AppStorage("Cleanup.Automatic.IncludeBookmarks") private var automaticCleanupIncludeBookmarks: Bool = false

    @State private var showManualCleanupAlert = false
    @State private var isCleaningUp = false
    @State private var showCleanupSuccess = false

    var body: some View {
        Section {
            Toggle(
                String(localized: "Cleanup.Automatic.Enabled", table: "DataManagement"),
                isOn: $automaticCleanupEnabled
            )
            if automaticCleanupEnabled {
                Picker(selection: $automaticCleanupCutoff) {
                    Text(String(localized: "Cleanup.Cutoff.Off", table: "DataManagement"))
                        .tag(CleanupCutoff.off)
                    Section(String(localized: "Cleanup.Cutoff.OlderThanHeader", table: "DataManagement")) {
                        Text(String(localized: "Cleanup.Last24Hours", table: "DataManagement"))
                            .tag(CleanupCutoff.last24Hours)
                        Text(String(localized: "Cleanup.Last7Days", table: "DataManagement"))
                            .tag(CleanupCutoff.last7Days)
                        Text(String(localized: "Cleanup.Last30Days", table: "DataManagement"))
                            .tag(CleanupCutoff.last30Days)
                    }
                } label: {
                    Text(String(localized: "Cleanup.Automatic.Picker", table: "DataManagement"))
                }
                .labelsVisibility(.visible)
                Toggle(
                    String(localized: "Cleanup.Automatic.IncludeBookmarks", table: "DataManagement"),
                    isOn: $automaticCleanupIncludeBookmarks
                )
            }

            Button {
                showManualCleanupAlert = true
            } label: {
                HStack {
                    Text(String(localized: "Cleanup.Title", table: "DataManagement"))
                        .foregroundStyle(.red)
                    Spacer()
                    if isCleaningUp {
                        ProgressView()
                    }
                }
            }
            .disabled(isCleaningUp)
        } footer: {
            Text(String(localized: "Cleanup.Automatic.Footer", table: "DataManagement"))
        }
        .animation(.smooth.speed(2.0), value: automaticCleanupEnabled)
        .alert(
            String(localized: "Cleanup.Title", table: "DataManagement"),
            isPresented: $showManualCleanupAlert
        ) {
            Button(String(localized: "Cleanup.Last24Hours", table: "DataManagement"), role: .destructive) {
                runManualCleanup(cutoff: .last24Hours)
            }
            Button(String(localized: "Cleanup.Last7Days", table: "DataManagement"), role: .destructive) {
                runManualCleanup(cutoff: .last7Days)
            }
            Button(String(localized: "Cleanup.Last30Days", table: "DataManagement"), role: .destructive) {
                runManualCleanup(cutoff: .last30Days)
            }
            Button("Shared.Cancel", role: .cancel) {}
        } message: {
            Text(String(localized: "Cleanup.Manual.Message", table: "DataManagement"))
        }
        .alert(
            String(localized: "Title", table: "DataManagement"),
            isPresented: $showCleanupSuccess
        ) {
            Button("Shared.OK") {}
        } message: {
            Text(String(localized: "Cleanup.Success", table: "DataManagement"))
        }
        .onChange(of: automaticCleanupEnabled) {
            AutomaticCleanupScheduler.scheduleNextCleanup()
        }
        .onChange(of: automaticCleanupCutoff) {
            AutomaticCleanupScheduler.scheduleNextCleanup()
        }
    }

    private func runManualCleanup(cutoff: CleanupCutoff) {
        guard let cutoffDate = cutoff.cutoffDate() else { return }
        isCleaningUp = true
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            await feedManager.deleteArticlesAndVacuum(olderThan: cutoffDate)
            UIApplication.shared.isIdleTimerDisabled = false
            isCleaningUp = false
            showCleanupSuccess = true
        }
    }
}
