import SwiftUI
import UserNotifications

struct AppearanceSettingsView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none

    var body: some View {
        List {
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
            } header: {
                Text(String(localized: "Section.DisplayStyles", table: "Settings"))
            }

            Section {
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
            } header: {
                Text(String(localized: "Section.Customization", table: "Settings"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Appearance", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
