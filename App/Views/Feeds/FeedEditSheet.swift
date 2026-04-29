import SwiftUI

enum FeedEditTab: Hashable {
    case metadata
    case content
    case rules
    case lists
}

struct FeedEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    let feedID: Int64

    @State private var selectedTab: FeedEditTab = .metadata

    var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                tabContent
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
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
                FeedEditMetadataTab(feedID: feedID)
                    .environment(feedManager)
            case .content:
                FeedEditContentTab(feedID: feedID)
                    .environment(feedManager)
            case .rules:
                FeedEditRulesTab(feedID: feedID)
                    .environment(feedManager)
            case .lists:
                FeedEditListsTab(feedID: feedID)
                    .environment(feedManager)
            }
        } else {
            Spacer()
        }
    }
}
