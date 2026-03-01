import SwiftUI

struct MoreView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("refreshInterval") private var refreshInterval: Int = 60
    @State private var isClearingCache = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Settings.DisplayStyle"), selection: Bindable(feedManager).displayStyle) {
                        Text(String(localized: "Articles.Style.Inbox")).tag(FeedDisplayStyle.inbox)
                        Text(String(localized: "Articles.Style.Magazine")).tag(FeedDisplayStyle.magazine)
                        Text(String(localized: "Articles.Style.Compact")).tag(FeedDisplayStyle.compact)
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
                    Button(role: .destructive) {
                        isClearingCache = true
                        Task {
                            await FaviconCache.shared.clearCache()
                            isClearingCache = false
                        }
                    } label: {
                        HStack {
                            Text(String(localized: "Settings.ClearFaviconCache"))
                            if isClearingCache {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isClearingCache)
                } header: {
                    Text(String(localized: "Settings.Section.Cache"))
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
