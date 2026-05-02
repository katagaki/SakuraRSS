import SwiftUI

struct BulkEditListsTab: View {

    @Environment(FeedManager.self) var feedManager
    let feedIDs: Set<Int64>
    var onApplied: () -> Void

    @State private var assignedListIDs: Set<Int64> = []
    @State private var initialAssignedListIDs: Set<Int64> = []
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
                }

                Section {
                    Button {
                        applyToAll()
                    } label: {
                        Text(String(
                            localized: "FeedList.BulkEdit.Lists.Apply.\(feedIDs.count)",
                            table: "Feeds"
                        ))
                    }
                    .disabled(feedIDs.isEmpty)
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
        let initial = common ?? []
        assignedListIDs = initial
        initialAssignedListIDs = initial
    }

    private func toggleAssignment(_ list: FeedList) {
        if assignedListIDs.contains(list.id) {
            assignedListIDs.remove(list.id)
        } else {
            assignedListIDs.insert(list.id)
        }
    }

    private func applyToAll() {
        let toAdd = assignedListIDs.subtracting(initialAssignedListIDs)
        let toRemove = initialAssignedListIDs.subtracting(assignedListIDs)
        let listsByID = Dictionary(uniqueKeysWithValues: feedManager.lists.map { ($0.id, $0) })
        for feedID in feedIDs {
            guard let feed = feedManager.feedsByID[feedID] else { continue }
            for listID in toAdd {
                guard let list = listsByID[listID] else { continue }
                feedManager.addFeedToList(list, feed: feed)
            }
            for listID in toRemove {
                guard let list = listsByID[listID] else { continue }
                feedManager.removeFeedFromList(list, feed: feed)
            }
        }
        onApplied()
    }
}
