import SwiftUI

struct EditFeedSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    let feedID: Int64

    @State private var selectedTab: FeedEditTab = .metadata

    var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        NavigationStack {
            tabContent
                .navigationTitle(navigationTitle)
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
        }
    }

    private var navigationTitle: String {
        feed?.title ?? String(localized: "FeedEdit.Title", table: "Feeds")
    }

    @ViewBuilder
    private var tabContent: some View {
        if feed != nil {
            switch selectedTab {
            case .metadata:
                EditFeedMetadataTab(feedID: feedID)
                    .environment(feedManager)
            case .content:
                EditFeedContentTab(feedID: feedID)
                    .environment(feedManager)
            case .rules:
                EditFeedRulesTab(feedID: feedID)
                    .environment(feedManager)
            case .lists:
                EditFeedListsTab(feedID: feedID)
                    .environment(feedManager)
            }
        } else {
            Spacer()
        }
    }
}
