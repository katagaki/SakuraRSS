import SwiftUI

struct ListFeedSelectionSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let list: FeedList

    @State private var selectedFeedIDs: Set<Int64> = []
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if feedManager.feeds.isEmpty {
                        Text(String(localized: "ListEdit.Feeds.Empty", table: "Lists"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(feedManager.feeds) { feed in
                            feedRow(feed)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "ListEdit.Feeds", table: "Lists"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        save()
                    }
                }
            }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                selectedFeedIDs = feedManager.feedIDs(for: list)
            }
        }
    }

    @ViewBuilder
    private func feedRow(_ feed: Feed) -> some View {
        Button {
            if selectedFeedIDs.contains(feed.id) {
                selectedFeedIDs.remove(feed.id)
            } else {
                selectedFeedIDs.insert(feed.id)
            }
        } label: {
            HStack(spacing: 12) {
                FeedIcon(feed: feed, size: 28, cornerRadius: 6)
                Text(feed.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedFeedIDs.contains(feed.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let currentIDs = feedManager.feedIDs(for: list)
        for id in selectedFeedIDs where !currentIDs.contains(id) {
            if let feed = feedManager.feedsByID[id] {
                feedManager.addFeedToList(list, feed: feed)
            }
        }
        for id in currentIDs where !selectedFeedIDs.contains(id) {
            if let feed = feedManager.feedsByID[id] {
                feedManager.removeFeedFromList(list, feed: feed)
            }
        }
        dismiss()
    }
}
