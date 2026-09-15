import SwiftUI
import Hanami

struct EditFeedSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    let feedID: Int64

    @State private var feed: Feed?
    @State private var selectedTab: FeedEditTab

    init(feedID: Int64, initialTab: FeedEditTab = .about) {
        self.feedID = feedID
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                tabContent(hasFeed: feed != nil)
            }
            .navigationTitle(feed?.title ?? String(localized: "FeedEdit.Title", table: "Feeds"))
            .navigationBarTitleDisplayMode(.inline)
            .compatibleSoftScrollEdgeEffectStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    // A menu rather than segments: five tabs no longer fit
                    // across the sheet without truncating their titles.
                    Menu {
                        Picker("", selection: $selectedTab) {
                            ForEach(FeedEditTab.allCases, id: \.self) { tab in
                                Text(tab.localizedTitle).tag(tab)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedTab.localizedTitle)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.headline)
                    }
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
            case .about:
                EditFeedMetadataTab(feed: $feed, feedID: feedID)
            case .content:
                EditFeedContentTab(feed: $feed, feedID: feedID)
            case .display:
                EditFeedDisplayTab(feedID: feedID)
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
