import SwiftUI

struct ListDetailView: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList

    @State private var listToEdit: FeedList?
    @State private var listForRules: FeedList?

    private var feedsInList: [Feed] {
        feedManager.feeds(for: list)
    }

    var body: some View {
        List {
            ForEach(feedsInList) { feed in
                NavigationLink(value: feed) {
                    FeedRowView(feed: feed)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        feedManager.removeFeedFromList(list, feed: feed)
                    } label: {
                        Label("ListDetail.RemoveFeed",
                              systemImage: "minus.circle")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(list.name)
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        listToEdit = list
                    } label: {
                        Label("ListMenu.Edit", systemImage: "pencil")
                    }
                    Button {
                        listForRules = list
                    } label: {
                        Label("ListMenu.Rules",
                              systemImage: "list.bullet.rectangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .overlay {
            if feedsInList.isEmpty {
                ContentUnavailableView {
                    Label("ListDetail.Empty.Title",
                          systemImage: "tray")
                } description: {
                    Text("ListDetail.Empty.Description")
                }
            }
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
    }
}
