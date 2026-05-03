import SwiftUI

struct MoreListsSection: View {

    @Environment(FeedManager.self) var feedManager
    @Binding var listToEdit: FeedList?
    @Binding var listForRules: FeedList?
    @Binding var listToDelete: FeedList?
    @Binding var isShowingNewList: Bool

    private var sortedLists: [FeedList] {
        feedManager.lists.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        Section {
            ForEach(sortedLists) { list in
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
                        Label(String(localized: "ListMenu.Delete", table: "Lists"), systemImage: "trash")
                    }
                }
            }
            Button {
                isShowingNewList = true
            } label: {
                Label(String(localized: "Section.Lists.NewList", table: "Settings"), systemImage: "plus")
            }
        } header: {
            Text(String(localized: "Section.Lists", table: "Settings"))
        }
    }

    @ViewBuilder
    private func listContextMenu(for list: FeedList) -> some View {
        Button {
            listToEdit = list
        } label: {
            Label(String(localized: "ListMenu.Edit", table: "Lists"), systemImage: "pencil")
        }
        Button {
            listForRules = list
        } label: {
            Label(String(localized: "ListMenu.Rules", table: "Lists"), systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button(role: .destructive) {
            listToDelete = list
        } label: {
            Label(String(localized: "ListMenu.Delete", table: "Lists"), systemImage: "trash")
        }
    }
}
