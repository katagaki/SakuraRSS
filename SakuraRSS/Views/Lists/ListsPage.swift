import SwiftUI

struct ListsPage: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isShowingNewList = false
    @State private var listToEdit: FeedList?
    @State private var listForRules: FeedList?
    @State private var listToDelete: FeedList?

    var body: some View {
        List {
            ForEach(feedManager.lists) { list in
                NavigationLink(value: list) {
                    ListRowView(list: list)
                }
                .contextMenu {
                    listContextMenu(for: list)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        listToDelete = list
                    } label: {
                        Label(String(localized: "ListMenu.Delete"), systemImage: "trash")
                    }
                }
            }
            .onMove { from, to in
                var reordered = feedManager.lists
                reordered.move(fromOffsets: from, toOffset: to)
                feedManager.reorderLists(reordered)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Lists.Title"))
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewList = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .overlay {
            if feedManager.lists.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Lists.Empty.Title"),
                          systemImage: "list.bullet.rectangle.portrait")
                } description: {
                    Text("Lists.Empty.Description")
                } actions: {
                    Button(String(localized: "Lists.Empty.CreateList")) {
                        isShowingNewList = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $isShowingNewList) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .sheet(item: $listToEdit) { list in
            ListEditSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .sheet(item: $listForRules) { list in
            ListRulesSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .confirmationDialog(
            String(localized: "ListMenu.Delete.Title"),
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "ListMenu.Delete.Confirm"), role: .destructive) {
                if let list = listToDelete {
                    feedManager.deleteList(list)
                    listToDelete = nil
                }
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) {
                listToDelete = nil
            }
        } message: {
            if let list = listToDelete {
                Text("ListMenu.Delete.Message.\(list.name)")
            }
        }
    }

    @ViewBuilder
    private func listContextMenu(for list: FeedList) -> some View {
        Button {
            listToEdit = list
        } label: {
            Label(String(localized: "ListMenu.Edit"), systemImage: "pencil")
        }
        Button {
            listForRules = list
        } label: {
            Label(String(localized: "ListMenu.Rules"), systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button(role: .destructive) {
            listToDelete = list
        } label: {
            Label(String(localized: "ListMenu.Delete"), systemImage: "trash")
        }
    }
}

struct ListRowView: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: list.icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.body)
                    .lineLimit(1)
                let count = feedManager.feedCount(for: list)
                Text("Lists.FeedCount \(count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let unread = feedManager.unreadCount(for: list)
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tertiary)
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
    }
}
