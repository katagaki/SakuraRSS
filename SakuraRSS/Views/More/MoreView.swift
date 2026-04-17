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
    @AppStorage("BackgroundRefresh.ImageBackfillWiFiOnly") private var imageBackfillWiFiOnly: Bool = true
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "Section.Analytics", table: "Settings")) {
                    AnalyticsView()
                }

                Section(String(localized: "Section.Display", table: "Settings")) {
                    Picker(selection: $defaultDisplayStyle) {
                        Text(String(localized: "Style.Inbox", table: "Articles"))
                            .tag(FeedDisplayStyle.inbox)
                        Text(String(localized: "Style.Compact", table: "Articles"))
                            .tag(FeedDisplayStyle.compact)
                        Text(String(localized: "Style.Feed", table: "Articles"))
                            .tag(FeedDisplayStyle.feed)
                    } label: {
                        Text(String(localized: "DefaultDisplayStyle", table: "Settings"))
                    }
                    Picker(selection: $markAllReadPosition) {
                        Text(String(localized: "MarkAllReadPosition.Bottom", table: "Settings"))
                            .tag(MarkAllReadPosition.bottom)
                        Text(String(localized: "MarkAllReadPosition.Top", table: "Settings"))
                            .tag(MarkAllReadPosition.top)
                        Text(String(localized: "MarkAllReadPosition.None", table: "Settings"))
                            .tag(MarkAllReadPosition.none)
                    } label: {
                        Text(String(localized: "MarkAllReadPosition", table: "Settings"))
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
                        Text(String(localized: "RefreshCooldown.Off", table: "Settings"))
                            .tag(FeedRefreshCooldown.off)
                        Text(String(localized: "RefreshCooldown.1min", table: "Settings"))
                            .tag(FeedRefreshCooldown.oneMinute)
                        Text(String(localized: "RefreshCooldown.5min", table: "Settings"))
                            .tag(FeedRefreshCooldown.fiveMinutes)
                        Text(String(localized: "RefreshCooldown.10min", table: "Settings"))
                            .tag(FeedRefreshCooldown.tenMinutes)
                        Text(String(localized: "RefreshCooldown.30min", table: "Settings"))
                            .tag(FeedRefreshCooldown.thirtyMinutes)
                        Text(String(localized: "RefreshCooldown.1hour", table: "Settings"))
                            .tag(FeedRefreshCooldown.oneHour)
                    } label: {
                        Text(String(localized: "RefreshCooldown", table: "Settings"))
                    }
                    Toggle(
                        String(localized: "BackgroundRefresh.WiFiOnlyImageBackfill", table: "Settings"),
                        isOn: $imageBackfillWiFiOnly
                    )
                } header: {
                    Text(String(localized: "Section.Refresh", table: "Settings"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "RefreshCooldown.Footer", table: "Settings"))
                        Text(String(localized: "BackgroundRefresh.WiFiOnlyImageBackfill.Footer", table: "Settings"))
                    }
                }

                Section(String(localized: "Section.Integrations", table: "Settings")) {
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
                    NavigationLink(String(localized: "Petal", table: "Integrations")) {
                        PetalSettingsView()
                    }
                }

                MoreDataManagementSection()

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
        }
    }
}
