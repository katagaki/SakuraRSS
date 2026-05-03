import SwiftUI

struct EditFeedListsTab: View {

    @Environment(FeedManager.self) var feedManager
    @Binding var feed: Feed?
    let feedID: Int64

    @State private var isShowingNewList = false

    private var assignedListIDs: Set<Int64> {
        guard let feed else { return [] }
        return feedManager.listIDsForFeed(feed)
    }

    var body: some View {
        Group {
            if let feed {
                listsList(for: feed)
            } else {
                Color.clear
            }
        }
        .sheet(isPresented: $isShowingNewList) {
            ListEditSheet(list: nil)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private func listsList(for feed: Feed) -> some View {
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
                            toggleAssignment(list, feed: feed)
                        } label: {
                            listRow(list)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    isShowingNewList = true
                } label: {
                    Label(String(localized: "AddToList.NewList", table: "Lists"),
                          systemImage: "plus")
                }
            }
        }
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

    private func toggleAssignment(_ list: FeedList, feed: Feed) {
        if assignedListIDs.contains(list.id) {
            feedManager.removeFeedFromList(list, feed: feed)
        } else {
            feedManager.addFeedToList(list, feed: feed)
        }
    }
}
