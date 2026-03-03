import SwiftUI

struct MoreView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("refreshInterval") private var refreshInterval: Int = 60
    @AppStorage("defaultDisplayStyle") private var defaultDisplayStyle: String = FeedDisplayStyle.inbox.rawValue
    @AppStorage("searchDisplayStyle") private var searchDisplayStyle: String = FeedDisplayStyle.inbox.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Settings.DisplayStyle"), selection: $defaultDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox.rawValue)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed.rawValue)
                        Text("Articles.Style.Magazine")
                            .tag(FeedDisplayStyle.magazine.rawValue)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact.rawValue)
                        Text("Articles.Style.Photos")
                            .tag(FeedDisplayStyle.photos.rawValue)
                    }
                    Picker(String(localized: "Settings.SearchDisplayStyle"), selection: $searchDisplayStyle) {
                        Text("Articles.Style.Inbox")
                            .tag(FeedDisplayStyle.inbox.rawValue)
                        Text("Articles.Style.Feed")
                            .tag(FeedDisplayStyle.feed.rawValue)
                        Text("Articles.Style.Magazine")
                            .tag(FeedDisplayStyle.magazine.rawValue)
                        Text("Articles.Style.Compact")
                            .tag(FeedDisplayStyle.compact.rawValue)
                        Text("Articles.Style.Photos")
                            .tag(FeedDisplayStyle.photos.rawValue)
                    }
                } header: {
                    Text("Settings.Section.Display")
                }

                Section {
                    Picker(String(localized: "Settings.RefreshInterval"), selection: $refreshInterval) {
                        Text("Settings.Refresh.15min").tag(15)
                        Text("Settings.Refresh.30min").tag(30)
                        Text("Settings.Refresh.1hour").tag(60)
                        Text("Settings.Refresh.4hours").tag(240)
                    }
                } header: {
                    Text("Settings.Section.Refresh")
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
            .scrollContentBackground(.hidden)
            .sakuraBackground()
        }
    }
}
