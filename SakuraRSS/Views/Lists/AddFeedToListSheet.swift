import SwiftUI

struct AddFeedToListSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let feed: Feed

    @State private var selectedListIDs: Set<Int64> = []
    @State private var isShowingNewList = false
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            List {
                if feedManager.lists.isEmpty {
                    Section {
                        Text("AddToList.NoLists")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(feedManager.lists) { list in
                            Button {
                                if selectedListIDs.contains(list.id) {
                                    selectedListIDs.remove(list.id)
                                } else {
                                    selectedListIDs.insert(list.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: list.icon)
                                        .font(.title3)
                                        .foregroundStyle(.accent)
                                        .frame(width: 32, height: 32)
                                    Text(list.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedListIDs.contains(list.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button {
                        isShowingNewList = true
                    } label: {
                        Label("AddToList.NewList",
                              systemImage: "plus")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("AddToList.Title")
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
                selectedListIDs = feedManager.listIDsForFeed(feed)
            }
            .sheet(isPresented: $isShowingNewList) {
                // After creating a new list, auto-select it
                if let newList = feedManager.lists.last {
                    selectedListIDs.insert(newList.id)
                }
            } content: {
                ListEditSheet(list: nil)
                    .environment(feedManager)
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled()
            }
        }
    }

    private func save() {
        let currentIDs = feedManager.listIDsForFeed(feed)
        // Add to newly selected lists
        for id in selectedListIDs where !currentIDs.contains(id) {
            if let list = feedManager.lists.first(where: { $0.id == id }) {
                feedManager.addFeedToList(list, feed: feed)
            }
        }
        // Remove from deselected lists
        for id in currentIDs where !selectedListIDs.contains(id) {
            if let list = feedManager.lists.first(where: { $0.id == id }) {
                feedManager.removeFeedFromList(list, feed: feed)
            }
        }
        dismiss()
    }
}
