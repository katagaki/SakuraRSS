import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct MoreView: View {

    var showsCloseButton: Bool = true

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 240
    @AppStorage("BackgroundRefresh.Cooldown") private var refreshCooldown: FeedRefreshCooldown = .fiveMinutes
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showImportModeChoice = false
    @State private var importedFileData: Data?
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showCleanupConfirmation = false
    @State private var selectedCleanupCutoff: Date?
    @State private var selectedCleanupLabel: String = ""
    @State private var isCleaningUp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AnalyticsView()
                } header: {
                    Text(String(localized: "Section.Analytics", table: "Settings"))
                }

                Section {
                    Picker(String(localized: "DefaultDisplayStyle", table: "Settings"), selection: $defaultDisplayStyle) {
                        Text(String(localized: "Style.Inbox", table: "Articles"))
                            .tag(FeedDisplayStyle.inbox)
                        Text(String(localized: "Style.Compact", table: "Articles"))
                            .tag(FeedDisplayStyle.compact)
                        Text(String(localized: "Style.Feed", table: "Articles"))
                            .tag(FeedDisplayStyle.feed)
                    }
                    Picker(String(localized: "MarkAllReadPosition", table: "Settings"), selection: $markAllReadPosition) {
                        Text(String(localized: "MarkAllReadPosition.Bottom", table: "Settings"))
                            .tag(MarkAllReadPosition.bottom)
                        Text(String(localized: "MarkAllReadPosition.Top", table: "Settings"))
                            .tag(MarkAllReadPosition.top)
                        Text(String(localized: "MarkAllReadPosition.None", table: "Settings"))
                            .tag(MarkAllReadPosition.none)
                    }
                    Picker(String(localized: "UnreadBadgeMode", table: "Settings"), selection: $unreadBadgeMode) {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Text(String(localized: "UnreadBadgeMode.HomeScreenOnly", table: "Settings"))
                                .tag(UnreadBadgeMode.homeScreenOnly)
                        } else {
                            Text(String(localized: "UnreadBadgeMode.HomeScreenAndHomeTab", table: "Settings"))
                                .tag(UnreadBadgeMode.homeScreenAndHomeTab)
                            Text(String(localized: "UnreadBadgeMode.HomeScreenOnly", table: "Settings"))
                                .tag(UnreadBadgeMode.homeScreenOnly)
                            Text(String(localized: "UnreadBadgeMode.HomeTabOnly", table: "Settings"))
                                .tag(UnreadBadgeMode.homeTabOnly)
                        }
                        Text(String(localized: "UnreadBadgeMode.Off", table: "Settings"))
                            .tag(UnreadBadgeMode.none)
                    }
                    .onChange(of: unreadBadgeMode) { _, newValue in
                        switch newValue {
                        case .homeScreenAndHomeTab, .homeScreenOnly:
                            Task {
                                let granted = try? await UNUserNotificationCenter.current()
                                    .requestAuthorization(options: [.badge])
                                if granted == true {
                                    feedManager.updateBadgeCount()
                                } else {
                                    unreadBadgeMode = newValue == .homeScreenAndHomeTab
                                        ? .homeTabOnly : .none
                                }
                            }
                        case .homeTabOnly, .none:
                            Task {
                                try? await UNUserNotificationCenter.current().setBadgeCount(0)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Section.Display", table: "Settings"))
                }

                Section {
                    Toggle(String(localized: "BackgroundRefresh", table: "Settings"), isOn: $backgroundRefreshEnabled)
                    if backgroundRefreshEnabled {
                        Picker(selection: $refreshInterval) {
                            Text(String(localized: "Refresh.15min", table: "Settings")).tag(15)
                            Text(String(localized: "Refresh.30min", table: "Settings")).tag(30)
                            Text(String(localized: "Refresh.1hour", table: "Settings")).tag(60)
                            Text(String(localized: "Refresh.4hours", table: "Settings")).tag(240)
                            Text(String(localized: "Refresh.8hours", table: "Settings")).tag(480)
                            Text(String(localized: "Refresh.12hours", table: "Settings")).tag(720)
                            Text(String(localized: "Refresh.24hours", table: "Settings")).tag(1440)
                        } label: {
                            Text(String(localized: "RefreshInterval", table: "Settings"))
                        }
                    }
                    Picker(selection: $refreshCooldown) {
                        Text(String(localized: "RefreshCooldown.Off", table: "Settings")).tag(FeedRefreshCooldown.off)
                        Text(String(localized: "RefreshCooldown.1min", table: "Settings")).tag(FeedRefreshCooldown.oneMinute)
                        Text(String(localized: "RefreshCooldown.5min", table: "Settings")).tag(FeedRefreshCooldown.fiveMinutes)
                        Text(String(localized: "RefreshCooldown.10min", table: "Settings")).tag(FeedRefreshCooldown.tenMinutes)
                        Text(String(localized: "RefreshCooldown.30min", table: "Settings")).tag(FeedRefreshCooldown.thirtyMinutes)
                        Text(String(localized: "RefreshCooldown.1hour", table: "Settings")).tag(FeedRefreshCooldown.oneHour)
                    } label: {
                        Text(String(localized: "RefreshCooldown", table: "Settings"))
                    }
                } header: {
                    Text(String(localized: "Section.Refresh", table: "Settings"))
                } footer: {
                    Text(String(localized: "RefreshCooldown.Footer", table: "Settings"))
                }

                Section {
                    NavigationLink(String(localized: "Section.InsightsAndIntelligence", table: "Settings")) {
                        OnDeviceIntelligenceSettingsView()
                    }
                    NavigationLink(String(localized: "Podcast", table: "Integrations")) {
                        PodcastSettingsView()
                    }
                    NavigationLink(String(localized: "YouTube", table: "Integrations")) {
                        YouTubeSettingsView()
                    }
                    NavigationLink(String(localized: "X", table: "Integrations")) {
                        XSettingsView()
                    }
                    NavigationLink(String(localized: "Instagram", table: "Integrations")) {
                        InstagramSettingsView()
                    }
                    NavigationLink(String(localized: "ClearThisPage", table: "Integrations")) {
                        ClearThisPageSettingsView()
                    }
                } header: {
                    Text(String(localized: "Section.Integrations", table: "Settings"))
                }

                Section {
                    NavigationLink(String(localized: "Title", table: "Labs")) {
                        LabsView()
                    }
                } header: {
                    Text(String(localized: "Section.Labs", table: "Settings"))
                }

                Section {
                    NavigationLink {
                        iCloudBackupView()
                    } label: {
                        HStack {
                            Text(String(localized: "iCloudBackup.Title", table: "DataManagement"))
                            Spacer()
                            if let lastBackup = iCloudBackupManager.shared.lastBackupDate {
                                Text(lastBackup, style: .relative)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        }
                    }
                    HStack(spacing: 0) {
                        Button {
                            isExporting = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                Text(String(localized: "ExportOPML", table: "DataManagement"))
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        Divider()
                        Button {
                            isImporting = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title2)
                                Text(String(localized: "ImportOPML", table: "DataManagement"))
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text(String(localized: "Section.DataManagement", table: "Settings"))
                } footer: {
                    Text(String(localized: "OPML.Footer", table: "DataManagement"))
                }

                Section {
                    Menu {
                        Button(String(localized: "Cleanup.Last24Hours", table: "DataManagement")) {
                            selectedCleanupCutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                            selectedCleanupLabel = String(localized: "Cleanup.Last24Hours", table: "DataManagement")
                            showCleanupConfirmation = true
                        }
                        Button(String(localized: "Cleanup.Last7Days", table: "DataManagement")) {
                            selectedCleanupCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                            selectedCleanupLabel = String(localized: "Cleanup.Last7Days", table: "DataManagement")
                            showCleanupConfirmation = true
                        }
                        Button(String(localized: "Cleanup.Last4Weeks", table: "DataManagement")) {
                            selectedCleanupCutoff = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())
                            selectedCleanupLabel = String(localized: "Cleanup.Last4Weeks", table: "DataManagement")
                            showCleanupConfirmation = true
                        }
                        Button(String(localized: "Cleanup.AllTime", table: "DataManagement")) {
                            selectedCleanupCutoff = nil
                            selectedCleanupLabel = String(localized: "Cleanup.AllTime", table: "DataManagement")
                            showCleanupConfirmation = true
                        }
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
                }

                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        HStack {
                            Text("More.SourceCode")
                            Spacer()
                            Text("katagaki/SakuraRSS")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink {
                        AttributesView()
                    } label: {
                        Text("More.Attribution")
                    }
                }

            }
            .animation(.smooth.speed(2.0), value: backgroundRefreshEnabled)
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .navigationTitle("Tabs.Profile")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: OPMLDocument(content: feedManager.exportOPML()),
                contentType: .opml,
                defaultFilename: "SakuraRSS.opml"
            ) { result in
                switch result {
                case .success:
                    alertMessage = String(localized: "Export.Success", table: "DataManagement")
                    showAlert = true
                case .failure:
                    alertMessage = String(localized: "Export.Error", table: "DataManagement")
                    showAlert = true
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.opml, .xml],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else {
                        alertMessage = String(localized: "Import.Error", table: "DataManagement")
                        showAlert = true
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        importedFileData = data
                        showImportModeChoice = true
                    } else {
                        alertMessage = String(localized: "Import.Error", table: "DataManagement")
                        showAlert = true
                    }
                case .failure:
                    alertMessage = String(localized: "Import.Error", table: "DataManagement")
                    showAlert = true
                }
            }
            .alert(
                String(localized: "Import.ModeTitle", table: "DataManagement"),
                isPresented: $showImportModeChoice
            ) {
                Button(String(localized: "Import.Merge", table: "DataManagement")) {
                    performImport(overwrite: false)
                }
                Button(String(localized: "Import.Overwrite", table: "DataManagement"), role: .destructive) {
                    performImport(overwrite: true)
                }
                Button("Shared.Cancel", role: .cancel) {
                    importedFileData = nil
                }
            } message: {
                Text(String(localized: "Import.ModeMessage", table: "DataManagement"))
            }
            .alert(String(localized: "Title", table: "DataManagement"), isPresented: $showAlert) {
                Button("Shared.OK") {}
            } message: {
                if let alertMessage {
                    Text(alertMessage)
                }
            }
            .alert(
                String(localized: "Cleanup.ConfirmTitle", table: "DataManagement"),
                isPresented: $showCleanupConfirmation
            ) {
                Button(String(localized: "Cleanup.Confirm", table: "DataManagement"), role: .destructive) {
                    isCleaningUp = true
                    UIApplication.shared.isIdleTimerDisabled = true
                    Task {
                        await feedManager.deleteArticlesAndVacuum(olderThan: selectedCleanupCutoff)
                        UIApplication.shared.isIdleTimerDisabled = false
                        isCleaningUp = false
                        alertMessage = String(localized: "Cleanup.Success", table: "DataManagement")
                        showAlert = true
                    }
                }
                Button("Shared.Cancel", role: .cancel) {}
            } message: {
                Text(String(localized: "Cleanup.ConfirmMessage \(selectedCleanupLabel)", table: "DataManagement"))
            }
        }
    }

    private func performImport(overwrite: Bool) {
        guard let data = importedFileData else { return }
        importedFileData = nil
        do {
            let count = try feedManager.importOPML(data: data, overwrite: overwrite)
            alertMessage = String(localized: "Import.Success \(count)", table: "DataManagement")
        } catch {
            alertMessage = String(localized: "Import.Error", table: "DataManagement")
        }
        showAlert = true
    }
}
