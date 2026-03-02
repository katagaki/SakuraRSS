import SwiftUI

struct MoreView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("refreshInterval") private var refreshInterval: Int = 60
    @AppStorage("defaultDisplayStyle") private var defaultDisplayStyle: String = FeedDisplayStyle.inbox.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Settings.DisplayStyle"), selection: $defaultDisplayStyle) {
                        Text(String(localized: "Articles.Style.Inbox"))
                            .tag(FeedDisplayStyle.inbox.rawValue)
                        Text(String(localized: "Articles.Style.Feed"))
                            .tag(FeedDisplayStyle.feed.rawValue)
                        Text(String(localized: "Articles.Style.Magazine"))
                            .tag(FeedDisplayStyle.magazine.rawValue)
                        Text(String(localized: "Articles.Style.Compact"))
                            .tag(FeedDisplayStyle.compact.rawValue)
                        Text(String(localized: "Articles.Style.Photos"))
                            .tag(FeedDisplayStyle.photos.rawValue)
                    }
                } header: {
                    Text(String(localized: "Settings.Section.Display"))
                }

                Section {
                    Picker(String(localized: "Settings.RefreshInterval"), selection: $refreshInterval) {
                        Text(String(localized: "Settings.Refresh.15min")).tag(15)
                        Text(String(localized: "Settings.Refresh.30min")).tag(30)
                        Text(String(localized: "Settings.Refresh.1hour")).tag(60)
                        Text(String(localized: "Settings.Refresh.4hours")).tag(240)
                    }
                } header: {
                    Text(String(localized: "Settings.Section.Refresh"))
                }

                Section {
                    HStack {
                        Text(String(localized: "Settings.FeedCount"))
                        Spacer()
                        Text("\(feedManager.feeds.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(String(localized: "Settings.ArticleCount"))
                        Spacer()
                        Text("\(feedManager.articles.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "Settings.Section.Stats"))
                }

                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        HStack {
                            Text(String(localized: "More.SourceCode"))
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
