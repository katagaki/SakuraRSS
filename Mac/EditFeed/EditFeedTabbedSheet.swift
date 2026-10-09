import Hanami
import SwiftUI

/// The feed editor, with its tabs in a segmented control along the top.
struct EditFeedTabbedSheet: View {

    @Environment(FeedManager.self) var feedManager
    @SheetDismiss private var dismiss
    let feedID: Int64

    @State private var feed: Feed?
    @State private var selectedTab: FeedEditTab

    init(feedID: Int64, initialTab: FeedEditTab) {
        self.feedID = feedID
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "FeedEdit.Title", table: "Feeds"), selection: $selectedTab) {
                ForEach(FeedEditTab.allCases, id: \.self) { tab in
                    Text(tab.localizedTitle).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.vertical, 12)
            Divider()
            NavigationStack {
                tabContent
            }
            .id(selectedTab)
            SheetActionBar {
                Button(String(localized: "Shared.Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 560)
        .onEscape { dismiss() }
        .task {
            feed = feedManager.feedsByID[feedID]
        }
        .onChange(of: feedManager.feedsByID[feedID]) { _, newValue in
            feed = newValue
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if feed != nil {
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
