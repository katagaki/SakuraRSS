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
                        Label(String(localized: "ListDetail.RemoveFeed", table: "Lists"),
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
                        Label(String(localized: "ListMenu.Edit", table: "Lists"), systemImage: "pencil")
                    }
                    Button {
                        listForRules = list
                    } label: {
                        Label(String(localized: "ListMenu.Rules", table: "Lists"),
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
                    Label(String(localized: "ListDetail.Empty.Title", table: "Lists"),
                          systemImage: "tray")
                } description: {
                    Text(String(localized: "ListDetail.Empty.Description", table: "Lists"))
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
