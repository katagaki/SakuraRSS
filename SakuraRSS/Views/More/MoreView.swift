import SwiftUI
import FoundationModels
import UniformTypeIdentifiers
import UserNotifications

struct MoreView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 60
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none
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
            List {
                Section {
                    Picker(String(localized: "Settings.DefaultDisplayStyle"), selection: $defaultDisplayStyle) {
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
                    Picker(String(localized: "Settings.MarkAllReadPosition"), selection: $markAllReadPosition) {
                        Text("Settings.MarkAllReadPosition.Bottom")
                            .tag(MarkAllReadPosition.bottom)
                        Text("Settings.MarkAllReadPosition.Top")
                            .tag(MarkAllReadPosition.top)
                        Text("Settings.MarkAllReadPosition.None")
                            .tag(MarkAllReadPosition.none)
                    }
                    Picker(String(localized: "Settings.UnreadBadgeMode"), selection: $unreadBadgeMode) {
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
                    Toggle(String(localized: "Settings.BackgroundRefresh"), isOn: $backgroundRefreshEnabled)
                    if backgroundRefreshEnabled {
                        Picker(selection: $refreshInterval) {
                            Text("Settings.Refresh.15min").tag(15)
                            Text("Settings.Refresh.30min").tag(30)
                            Text("Settings.Refresh.1hour").tag(60)
                            Text("Settings.Refresh.4hours").tag(240)
                        } label: {
                            Text(String(localized: "Settings.RefreshInterval"))
                        }
                    }
                } header: {
                    Text("Settings.Section.Refresh")
                }

                Section {
                    if isAppleIntelligenceAvailable {
                        NavigationLink("Settings.Section.AppleIntelligence") {
                            AppleIntelligenceSettingsView()
                        }
                    }
                    NavigationLink("Integrations.YouTube") {
                        YouTubeSettingsView()
                    }
                } header: {
                    Text("Settings.Section.Integrations")
                }

                Section {
                    HStack(spacing: 0) {
                        Button {
                            isExporting = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                Text(String(localized: "DataManagement.ExportOPML"))
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
                                Text(String(localized: "DataManagement.ImportOPML"))
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
                    NavigationLink {
                        LabsView()
                    } label: {
                        Text(String(localized: "More.Labs"))
                    }
                }

                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        HStack {
                            Text(String(localized: "More.SourceCode"))
                            Spacer()
                            Text("katagaki/SakuraRSS")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink {
                        AttributesView()
                    } label: {
                        Text(String(localized: "More.Attribution"))
                    }
                }

            }
            .animation(.smooth.speed(2.0), value: backgroundRefreshEnabled)
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .navigationTitle(String(localized: "Tabs.More"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
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
