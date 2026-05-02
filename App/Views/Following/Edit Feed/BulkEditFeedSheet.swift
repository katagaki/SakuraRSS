import SwiftUI

enum BulkEditTab: Hashable {
    case content
    case lists
}

struct BulkEditFeedSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    let feedIDs: Set<Int64>

    @State private var selectedTab: BulkEditTab = .content

    var body: some View {
        NavigationStack {
            ZStack {
                tabContent
            }
            .navigationTitle(String(
                localized: "FeedList.BulkEdit.Title.\(feedIDs.count)",
                table: "Feeds"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedTab) {
                        Text(String(localized: "FeedEditSheet.Tab.Content", table: "Feeds"))
                            .tag(BulkEditTab.content)
                        Text(String(localized: "FeedEditSheet.Tab.Lists", table: "Feeds"))
                            .tag(BulkEditTab.lists)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .content:
            BulkEditContentTab(feedIDs: feedIDs, onApplied: { dismiss() })
        case .lists:
            BulkEditListsTab(feedIDs: feedIDs)
        }
    }
}
