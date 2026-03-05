import SwiftUI
import FoundationModels
import UniformTypeIdentifiers
import UserNotifications

struct MoreView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 60
    @AppStorage("BackgroundRefresh.BadgeEnabled") private var badgeEnabled: Bool = false
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("TodaysSummary.Enabled") private var todaysSummaryEnabled: Bool = true
    @AppStorage("WhileYouSlept.Enabled") private var whileYouSleptEnabled: Bool = true
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showImportModeChoice = false
    @State private var importedFileData: Data?
    @State private var alertMessage: String?
    @State private var showAlert = false

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Settings.DisplayStyle"), selection: $defaultDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed)
                    }
                    Picker(String(localized: "Settings.SearchDisplayStyle"), selection: $searchDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed)
                    }
                } header: {
                    Text("Settings.Section.Display")
                }

                Section {
                    Toggle(String(localized: "Settings.BackgroundRefresh"), isOn: $backgroundRefreshEnabled)
                    if backgroundRefreshEnabled {
                        Picker(String(localized: "Settings.RefreshInterval"), selection: $refreshInterval) {
                            Text("Settings.Refresh.15min").tag(15)
                            Text("Settings.Refresh.30min").tag(30)
                            Text("Settings.Refresh.1hour").tag(60)
                            Text("Settings.Refresh.4hours").tag(240)
                        }
                        Toggle(String(localized: "Settings.BadgeEnabled"), isOn: $badgeEnabled)
                            .onChange(of: badgeEnabled) { _, isEnabled in
                                if isEnabled {
                                    Task {
                                        let granted = try? await UNUserNotificationCenter.current()
                                            .requestAuthorization(options: [.badge])
                                        if granted == true {
                                            let count = feedManager.totalUnreadCount()
                                            try? await UNUserNotificationCenter.current().setBadgeCount(count)
                                        } else {
                                            badgeEnabled = false
                                        }
                                    }
                                } else {
                                    UNUserNotificationCenter.current().setBadgeCount(0)
                                }
                            }
                    }
                } header: {
                    Text("Settings.Section.Refresh")
                }

                if isAppleIntelligenceAvailable {
                    Section {
                        Toggle(String(localized: "Settings.WhileYouSlept"), isOn: $whileYouSleptEnabled)
                        Toggle(String(localized: "Settings.TodaysSummary"), isOn: $todaysSummaryEnabled)
                    } header: {
                        Text("Settings.Section.AppleIntelligence")
                    } footer: {
                        Text("Settings.AppleIntelligence.Footer")
                    }
                }

                Section {
                    Button {
                        isExporting = true
                    } label: {
                        Label(String(localized: "DataManagement.ExportOPML"), systemImage: "square.and.arrow.up")
                    }
                    Button {
                        isImporting = true
                    } label: {
                        Label(String(localized: "DataManagement.ImportOPML"), systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Settings.Section.DataManagement")
                } footer: {
                    Text("DataManagement.OPML.Footer")
                }


                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        HStack {
                            Text("More.SourceCode")
                            Spacer()
                            Text("katagaki/SakuraRSS")
                                .foregroundStyle(.secondary)
                            Image(systemName: "safari")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink(String(localized: "More.Attribution")) {
                        AttributesView()
                    }
                }
            }
            .navigationTitle(String(localized: "Tabs.More"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollContentBackground(.hidden)
            .sakuraBackground()
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
                String(localized: "DataManagement.Import.ModeTitle"),
                isPresented: $showImportModeChoice
            ) {
                Button(String(localized: "DataManagement.Import.Merge")) {
                    performImport(overwrite: false)
                }
                Button(String(localized: "DataManagement.Import.Overwrite"), role: .destructive) {
                    performImport(overwrite: true)
                }
                Button(String(localized: "Shared.Cancel"), role: .cancel) {
                    importedFileData = nil
                }
            } message: {
                Text("DataManagement.Import.ModeMessage")
            }
            .alert(String(localized: "DataManagement.Title"), isPresented: $showAlert) {
                Button(String(localized: "Shared.OK")) {}
            } message: {
                if let alertMessage {
                    Text(alertMessage)
                }
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
