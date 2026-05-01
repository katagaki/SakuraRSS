import SwiftUI

struct EditFeedSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    let feedID: Int64

    @State private var feed: Feed?
    @State private var selectedTab: FeedEditTab = .metadata

    var body: some View {
        NavigationStack {
            ZStack {
                tabContent(hasFeed: feed != nil)
            }
            .navigationTitle(feed?.title ?? String(localized: "FeedEdit.Title", table: "Feeds"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedTab) {
                        Text(String(localized: "FeedEditSheet.Tab.Metadata", table: "Feeds"))
                            .tag(FeedEditTab.metadata)
                        Text(String(localized: "FeedEditSheet.Tab.Content", table: "Feeds"))
                            .tag(FeedEditTab.content)
                        Text(String(localized: "FeedEditSheet.Tab.Rules", table: "Feeds"))
                            .tag(FeedEditTab.rules)
                        Text(String(localized: "FeedEditSheet.Tab.Lists", table: "Feeds"))
                            .tag(FeedEditTab.lists)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .task {
                feed = feedManager.feedsByID[feedID]
            }
            .onChange(of: feedManager.feedsByID[feedID]) { _, newValue in
                feed = newValue
            }
        }
    }

    @ViewBuilder
    private func tabContent(hasFeed: Bool) -> some View {
        if hasFeed {
            switch selectedTab {
            case .metadata:
                EditFeedMetadataTab(feed: $feed, feedID: feedID)
            case .content:
                EditFeedContentTab(feed: $feed, feedID: feedID)
            case .rules:
                EditFeedRulesTab(feed: $feed, feedID: feedID)
            case .lists:
                EditFeedListsTab(feed: $feed, feedID: feedID)
            }
        } else {
            Spacer()
        }
    }
}
