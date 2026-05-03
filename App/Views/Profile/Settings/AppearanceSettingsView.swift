import SwiftUI
import UserNotifications

struct AppearanceSettingsView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .top
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none
    @AppStorage("Display.ZoomTransition") private var zoomTransitionEnabled: Bool = true
    @AppStorage("Display.SakuraBackground") private var sakuraBackgroundEnabled: Bool = true
    @AppStorage("Display.FeedBackground") private var feedBackgroundEnabled: Bool = true

    var body: some View {
        List {
            #if !os(visionOS) && !targetEnvironment(macCatalyst)
            Section {
                Toggle(String(localized: "SakuraBackground", table: "Settings"),
                       isOn: $sakuraBackgroundEnabled)
                .tint(.accent)
                Toggle(String(localized: "FeedBackground", table: "Settings"),
                       isOn: $feedBackgroundEnabled)
            } header: {
                Text(String(localized: "Section.Theme", table: "Settings"))
            }
            #endif

            Section {
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
                Picker(selection: $searchDisplayStyle) {
                    Text(String(localized: "Style.Inbox", table: "Articles"))
                        .tag(FeedDisplayStyle.inbox)
                    Text(String(localized: "Style.Compact", table: "Articles"))
                        .tag(FeedDisplayStyle.compact)
                    Text(String(localized: "Style.Feed", table: "Articles"))
                        .tag(FeedDisplayStyle.feed)
                } label: {
                    Text(String(localized: "SearchDisplayStyle", table: "Settings"))
                }
            } header: {
                Text(String(localized: "Section.DisplayStyles", table: "Settings"))
            }

            Section {
                Toggle(String(localized: "ZoomTransition", table: "Settings"),
                       isOn: $zoomTransitionEnabled)
            } header: {
                Text(String(localized: "Section.Navigation", table: "Settings"))
            }

            Section {
                Toggle(String(localized: "ShowMarkAllRead", table: "Settings"),
                       isOn: Binding(
                            get: { markAllReadPosition == .top },
                            set: { markAllReadPosition = $0 ? .top : .none }
                       ))
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
                Text(String(localized: "Section.ReadStatus", table: "Settings"))
            }
        }
        .listStyle(.insetGrouped)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Appearance", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
