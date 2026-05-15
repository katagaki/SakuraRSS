import SwiftUI
import Hanami

struct FollowingPage: View {

    @Environment(FeedManager.self) var feedManager
    @State var searchText = ""
    @State var isPresentingAddFeedSheet = false
    @State var feedToEdit: Feed?
    @State var feedToDelete: Feed?
    @State var isEditingFeeds = false
    @State var isSelectingFeeds = false
    @State var selectedFeedIDs: Set<Int64> = []
    @State var isPresentingBulkEditSheet = false
    @State var isPresentingBulkDeleteAlert = false
    @State var isPresentingNewListSheet = false
    @State var listToDelete: FeedList?
    @Namespace var addFeedNamespace
    @Namespace var feedEditNamespace
    @Namespace var newListNamespace

    let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var selectedFeeds: [Feed] {
        selectedFeedIDs.compactMap { feedManager.feedsByID[$0] }
    }

    var body: some View {
        ZStack {
            ScrollView {
                feedSectionsContent
                    .padding()
                    .animation(.smooth.speed(2.0), value: feedManager.feeds)
                    .animation(.smooth.speed(2.0), value: feedManager.lists)
                    .animation(.smooth.speed(2.0), value: searchText)
                    .animation(.smooth.speed(2.0), value: isEditingFeeds)
                    .animation(.smooth.speed(2.0), value: isSelectingFeeds)
                    .animation(.smooth.speed(2.0), value: selectedFeedIDs)
            }
        }
        .navigationTitle("Shared.Feeds")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, prompt: Text(String(localized: "FeedList.SearchPrompt", table: "Feeds")))
        .toolbar { toolbarContent }
        .sakuraBackground()
        .overlay { emptyStateOverlay }
        .sheet(isPresented: $isPresentingAddFeedSheet) {
            AddFeedView()
                .environment(feedManager)
                .presentationDetents([.large])
                .navigationTransition(.zoom(sourceID: "addFeed", in: addFeedNamespace))
        }
        .sheet(item: $feedToEdit) { feed in
            EditFeedSheet(feedID: feed.id)
                .environment(feedManager)
                .navigationTransition(.zoom(sourceID: feed.id, in: feedEditNamespace))
        }
        .sheet(isPresented: $isPresentingBulkEditSheet) {
            BulkEditFeedSheet(feedIDs: selectedFeedIDs)
                .environment(feedManager)
        }
        .sheet(isPresented: $isPresentingNewListSheet) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .navigationTransition(.zoom(sourceID: "newList", in: newListNamespace))
        }
        .alert(
            String(localized: "FeedMenu.Unfollow.Title", table: "Feeds"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            )
        ) {
            Button(String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"), role: .destructive) {
                if let feed = feedToDelete {
                    withAnimation(.smooth.speed(2.0)) {
                        try? feedManager.deleteFeed(feed)
                    }
                    feedToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text(String(localized: "FeedMenu.Unfollow.Message.\(feed.title)", table: "Feeds"))
            }
        }
        .alert(
            String(localized: "ListMenu.Delete.Title", table: "Lists"),
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            )
        ) {
            Button(String(localized: "ListMenu.Delete.Confirm", table: "Lists"), role: .destructive) {
                if let list = listToDelete {
                    withAnimation(.smooth.speed(2.0)) {
                        feedManager.deleteList(list)
                    }
                    listToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                listToDelete = nil
            }
        } message: {
            if let list = listToDelete {
                Text(String(localized: "ListMenu.Delete.Message.\(list.name)", table: "Lists"))
            }
        }
        .alert(
            String(localized: "FeedList.BulkDelete.Title", table: "Feeds"),
            isPresented: $isPresentingBulkDeleteAlert
        ) {
            Button(String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"), role: .destructive) {
                deleteSelectedFeeds()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(
                localized: "FeedList.BulkDelete.Message.\(selectedFeedIDs.count)",
                table: "Feeds"
            ))
        }
    }
}

extension FollowingPage {

    func toggleSelection(_ feed: Feed) {
        withAnimation(.smooth.speed(2.0)) {
            if selectedFeedIDs.contains(feed.id) {
                selectedFeedIDs.remove(feed.id)
            } else {
                selectedFeedIDs.insert(feed.id)
            }
        }
    }

    func toggleSelectMode() {
        if isSelectingFeeds {
            isSelectingFeeds = false
            selectedFeedIDs = []
        } else {
            isSelectingFeeds = true
        }
    }

    func exitEditMode() {
        isSelectingFeeds = false
        selectedFeedIDs = []
        isEditingFeeds = false
    }

    func deleteSelectedFeeds() {
        let feedsToDelete = selectedFeeds
        withAnimation(.smooth.speed(2.0)) {
            for feed in feedsToDelete {
                try? feedManager.deleteFeed(feed)
            }
            selectedFeedIDs = []
            isSelectingFeeds = false
        }
    }
}
