import EnhancedNavigation
import SwiftUI
import Hanami

struct FollowingPage: View {

    @Environment(FeedManager.self) var feedManager
    let followingNavigationNamespace: Namespace.ID
    @State var searchText = ""
    @State var isPresentingAddFeedSheet = false
    @State private var addFeedSession = AddFeedSession()
    @State var feedToEdit: Feed?
    @State var feedForRules: Feed?
    @State var feedToDelete: Feed?
    @State var isEditingFeeds = false
    @State var isSelectingFeeds = false
    @State var isShowingAllDespiteFocus = false
    @State var selectedFeedIDs: Set<Int64> = []
    @State var isPresentingBulkEditSheet = false
    @State var isPresentingBulkDeleteAlert = false
    @State var isPresentingNewListSheet = false
    @Namespace var feedEditNamespace

    let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var selectedFeeds: [Feed] {
        selectedFeedIDs.compactMap { feedManager.feedsByID[$0] }
    }

    var applyFocus: Bool {
        feedManager.isFocusEffective && !isShowingAllDespiteFocus
    }

    var body: some View {
        ZStack {
            ScrollView {
                feedSectionsContent
                    .padding()
                    .animation(.smooth.speed(2.0), value: feedManager.feeds)
                    .animation(.smooth.speed(2.0), value: searchText)
                    .animation(.smooth.speed(2.0), value: isEditingFeeds)
                    .animation(.smooth.speed(2.0), value: isSelectingFeeds)
                    .animation(.smooth.speed(2.0), value: selectedFeedIDs)
            }
        }
        .navigationTitle("Shared.Feeds")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer,
            prompt: Text(String(localized: "FeedList.SearchPrompt", table: "Feeds")))
        .sakuraBackground()
        .overlay { emptyStateOverlay }
        .onChange(of: feedManager.activeFocus) { _, _ in
            isShowingAllDespiteFocus = false
        }
        // The browser hides the top bar, so these controls go in the
        // omnibox's menu instead.
        .tabOmniboxAccessory {
            BrowserFollowingMenu(actions: browserFollowingActions)
        }
        .sheet(isPresented: $isPresentingAddFeedSheet) {
            AddFeedView(session: addFeedSession)
                .environment(feedManager)
                .presentationDetents([.large])
        }
        .sheet(item: $feedToEdit) { feed in
            EditFeedSheet(feedID: feed.id)
                .environment(feedManager)
                .navigationTransition(.zoom(sourceID: feed.id, in: feedEditNamespace))
        }
        .sheet(item: $feedForRules) { feed in
            EditFeedSheet(feedID: feed.id, initialTab: .rules)
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
