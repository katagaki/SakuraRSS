import SwiftUI

struct BulkEditListsTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedIDs: Set<Int64>

    @State private var assignedListIDs: Set<Int64> = []
    @State private var hasInitialized = false

    var body: some View {
        Form {
            if feedManager.lists.isEmpty {
                Section {
                    Text(String(localized: "AddToList.NoLists", table: "Lists"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(feedManager.lists) { list in
                        Button {
                            toggleAssignment(list)
                        } label: {
                            listRow(list)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text(String(
                        localized: "FeedList.BulkEdit.Lists.Footer.\(feedIDs.count)",
                        table: "Feeds"
                    ))
                }
            }
        }
        .onAppear { initializeIfNeeded() }
    }

    private func listRow(_ list: FeedList) -> some View {
        HStack(spacing: 12) {
            Image(systemName: list.icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32, height: 32)
            Text(list.name)
                .foregroundStyle(.primary)
            Spacer()
            if assignedListIDs.contains(list.id) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.accent)
            }
        }
        .contentShape(.rect)
    }

    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        var common: Set<Int64>?
        for feedID in feedIDs {
            guard let feed = feedManager.feedsByID[feedID] else { continue }
            let ids = feedManager.listIDsForFeed(feed)
            if let existing = common {
                common = existing.intersection(ids)
            } else {
                common = ids
            }
        }
        assignedListIDs = common ?? []
    }

    private func toggleAssignment(_ list: FeedList) {
        let isAssigning = !assignedListIDs.contains(list.id)
        for feedID in feedIDs {
            guard let feed = feedManager.feedsByID[feedID] else { continue }
            if isAssigning {
                feedManager.addFeedToList(list, feed: feed)
            } else {
                feedManager.removeFeedFromList(list, feed: feed)
            }
        }
        if isAssigning {
            assignedListIDs.insert(list.id)
        } else {
            assignedListIDs.remove(list.id)
        }
    }
}
