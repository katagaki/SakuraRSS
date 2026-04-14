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
                    Text("Settings.Section.Analytics")
                }

                Section {
                    Picker("Settings.DefaultDisplayStyle", selection: $defaultDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed)
                    }
                    Picker("Settings.MarkAllReadPosition", selection: $markAllReadPosition) {
                        Text("Settings.MarkAllReadPosition.Bottom")
                            .tag(MarkAllReadPosition.bottom)
                        Text("Settings.MarkAllReadPosition.Top")
                            .tag(MarkAllReadPosition.top)
                        Text("Settings.MarkAllReadPosition.None")
                            .tag(MarkAllReadPosition.none)
                    }
                    Picker("Settings.UnreadBadgeMode", selection: $unreadBadgeMode) {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Text("Settings.UnreadBadgeMode.HomeScreenOnly")
                                .tag(UnreadBadgeMode.homeScreenOnly)
                        } else {
                            Text("Settings.UnreadBadgeMode.HomeScreenAndHomeTab")
                                .tag(UnreadBadgeMode.homeScreenAndHomeTab)
                            Text("Settings.UnreadBadgeMode.HomeScreenOnly")
                                .tag(UnreadBadgeMode.homeScreenOnly)
                            Text("Settings.UnreadBadgeMode.HomeTabOnly")
                                .tag(UnreadBadgeMode.homeTabOnly)
                        }
                        Text("Settings.UnreadBadgeMode.Off")
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
                    Text("Settings.Section.Display")
                }

                Section {
                    Toggle("Settings.BackgroundRefresh", isOn: $backgroundRefreshEnabled)
                    if backgroundRefreshEnabled {
                        Picker(selection: $refreshInterval) {
                            Text("Settings.Refresh.15min").tag(15)
                            Text("Settings.Refresh.30min").tag(30)
                            Text("Settings.Refresh.1hour").tag(60)
                            Text("Settings.Refresh.4hours").tag(240)
                            Text("Settings.Refresh.8hours").tag(480)
                            Text("Settings.Refresh.12hours").tag(720)
                            Text("Settings.Refresh.24hours").tag(1440)
                        } label: {
                            Text("Settings.RefreshInterval")
                        }
                    }
                    Picker(selection: $refreshCooldown) {
                        Text("Settings.RefreshCooldown.Off").tag(FeedRefreshCooldown.off)
                        Text("Settings.RefreshCooldown.1min").tag(FeedRefreshCooldown.oneMinute)
                        Text("Settings.RefreshCooldown.5min").tag(FeedRefreshCooldown.fiveMinutes)
                        Text("Settings.RefreshCooldown.10min").tag(FeedRefreshCooldown.tenMinutes)
                        Text("Settings.RefreshCooldown.30min").tag(FeedRefreshCooldown.thirtyMinutes)
                        Text("Settings.RefreshCooldown.1hour").tag(FeedRefreshCooldown.oneHour)
                    } label: {
                        Text("Settings.RefreshCooldown")
                    }
                } header: {
                    Text("Settings.Section.Refresh")
                } footer: {
                    Text("Settings.RefreshCooldown.Footer")
                }

                Section {
                    NavigationLink("Settings.Section.InsightsAndIntelligence") {
                        OnDeviceIntelligenceSettingsView()
                    }
                    NavigationLink("Integrations.Podcast") {
                        PodcastSettingsView()
                    }
                    NavigationLink("Integrations.YouTube") {
                        YouTubeSettingsView()
                    }
                    NavigationLink("Integrations.X") {
                        XSettingsView()
                    }
                    NavigationLink("Integrations.Instagram") {
                        InstagramSettingsView()
                    }
                    NavigationLink("Integrations.ClearThisPage") {
                        ClearThisPageSettingsView()
                    }
                } header: {
                    Text("Settings.Section.Integrations")
                }

                Section {
                    NavigationLink {
                        iCloudBackupView()
                    } label: {
                        HStack {
                            Text("iCloudBackup.Title")
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
                                Text("DataManagement.ExportOPML")
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
                                Text("DataManagement.ImportOPML")
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Settings.Section.DataManagement")
                } footer: {
                    Text("DataManagement.OPML.Footer")
                }

                Section {
                    Menu {
                        Button("DataManagement.Cleanup.Last24Hours") {
                            selectedCleanupCutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                            selectedCleanupLabel = String(localized: "DataManagement.Cleanup.Last24Hours")
                            showCleanupConfirmation = true
                        }
                        Button("DataManagement.Cleanup.Last7Days") {
                            selectedCleanupCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                            selectedCleanupLabel = String(localized: "DataManagement.Cleanup.Last7Days")
                            showCleanupConfirmation = true
                        }
                        Button("DataManagement.Cleanup.Last4Weeks") {
                            selectedCleanupCutoff = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())
                            selectedCleanupLabel = String(localized: "DataManagement.Cleanup.Last4Weeks")
                            showCleanupConfirmation = true
                        }
                        Button("DataManagement.Cleanup.AllTime") {
                            selectedCleanupCutoff = nil
                            selectedCleanupLabel = String(localized: "DataManagement.Cleanup.AllTime")
                            showCleanupConfirmation = true
                        }
                    } label: {
                        HStack {
                            Text("DataManagement.Cleanup.Title")
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
                    alertMessage = String(localized: "DataManagement.Export.Success")
                    showAlert = true
                case .failure:
                    alertMessage = String(localized: "DataManagement.Export.Error")
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
                        alertMessage = String(localized: "DataManagement.Import.Error")
                        showAlert = true
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        importedFileData = data
                        showImportModeChoice = true
                    } else {
                        alertMessage = String(localized: "DataManagement.Import.Error")
                        showAlert = true
                    }
                case .failure:
                    alertMessage = String(localized: "DataManagement.Import.Error")
                    showAlert = true
                }
            }
            .alert(
                "DataManagement.Import.ModeTitle",
                isPresented: $showImportModeChoice
            ) {
                Button("DataManagement.Import.Merge") {
                    performImport(overwrite: false)
                }
                Button("DataManagement.Import.Overwrite", role: .destructive) {
                    performImport(overwrite: true)
                }
                Button("Shared.Cancel", role: .cancel) {
                    importedFileData = nil
                }
            } message: {
                Text("DataManagement.Import.ModeMessage")
            }
            .alert("DataManagement.Title", isPresented: $showAlert) {
                Button("Shared.OK") {}
            } message: {
                if let alertMessage {
                    Text(alertMessage)
                }
            }
            .alert(
                "DataManagement.Cleanup.ConfirmTitle",
                isPresented: $showCleanupConfirmation
            ) {
                Button("DataManagement.Cleanup.Confirm", role: .destructive) {
                    isCleaningUp = true
                    UIApplication.shared.isIdleTimerDisabled = true
                    Task {
                        await feedManager.deleteArticlesAndVacuum(olderThan: selectedCleanupCutoff)
                        UIApplication.shared.isIdleTimerDisabled = false
                        isCleaningUp = false
                        alertMessage = String(localized: "DataManagement.Cleanup.Success")
                        showAlert = true
                    }
                }
                Button("Shared.Cancel", role: .cancel) {}
            } message: {
                Text("DataManagement.Cleanup.ConfirmMessage \(selectedCleanupLabel)")
            }
        }
    }

    private func performImport(overwrite: Bool) {
        guard let data = importedFileData else { return }
        importedFileData = nil
        do {
            let count = try feedManager.importOPML(data: data, overwrite: overwrite)
            alertMessage = String(localized: "DataManagement.Import.Success \(count)")
        } catch {
            alertMessage = String(localized: "DataManagement.Import.Error")
        }
        showAlert = true
    }
}
