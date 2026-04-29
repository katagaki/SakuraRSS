import SwiftUI

struct AddFeedView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    var initialURL: String = ""
    @SceneStorage("AddFeedView.urlInput") var urlInput = ""
    @SceneStorage("AddFeedView.hasInitialized") var hasInitialized = false
    @State var discoveredFeeds: [DiscoveredFeed] = []
    @State var isSearching = false
    @State var errorMessage: String?
    @State var addedURLs: Set<String> = []
    @State var listMembership: [Int64: Set<Int64>] = [:]
    @State var showXLogin = false
    @State var pendingXFeed: DiscoveredFeed?
    @State var showInstagramLogin = false
    @State var pendingInstagramFeed: DiscoveredFeed?
    @State var suggestedTopics: [SuggestedTopic] = []
    @State var showPetalBuilder = false
    @AppStorage("Labs.PetalRecipes") var petalRecipesEnabled: Bool = false
    @FocusState var isURLFieldFocused: Bool

    private var petalSeedURL: String {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "" : normalizeURL(trimmed)
    }

    var body: some View {
        NavigationStack {
            Form {
                AddFeedSearchSection(
                    urlInput: $urlInput,
                    isSearching: isSearching,
                    isURLFieldFocused: $isURLFieldFocused,
                    onSubmit: searchFeeds
                )

                if urlInput.isEmpty {
                    AddFeedSuggestedTopicsSection(
                        topics: suggestedTopics,
                        addedURLs: addedURLs,
                        onAdd: addSuggestedFeed
                    )

                    RSSDiscoverySection()
                }

                if let errorMessage {
                    AddFeedErrorSection(
                        errorMessage: errorMessage,
                        showPetalGenerate: petalRecipesEnabled && !urlInput.isEmpty,
                        onGeneratePetal: { showPetalBuilder = true }
                    )
                }

                if !discoveredFeeds.isEmpty {
                    AddFeedDiscoveredSection(
                        feeds: discoveredFeeds,
                        addedURLs: addedURLs,
                        onAdd: addFeed
                    )
                }

                if !addedURLs.isEmpty && !feedManager.lists.isEmpty {
                    AddFeedListMembershipSection(
                        lists: feedManager.lists,
                        addedFeedIDs: addedFeedIDsSet,
                        listMembership: listMembership,
                        onToggle: toggleListForAddedFeeds
                    )
                }
            }
            .animation(.smooth.speed(2.0), value: urlInput.isEmpty)
            .navigationTitle(String(localized: "AddFeed.Title", table: "Feeds"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        urlInput = ""
                        hasInitialized = false
                        dismiss()
                    }
                }
            }
            .onAppear(perform: handleAppear)
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showXLogin) {
            if let pending = pendingXFeed {
                addFeedAfterXLogin(pending)
            }
        } content: {
            XLoginView()
        }
        .sheet(isPresented: $showInstagramLogin) {
            if let pending = pendingInstagramFeed {
                addFeedAfterInstagramLogin(pending)
            }
        } content: {
            InstagramLoginView()
        }
        .sheet(isPresented: $showPetalBuilder) {
            PetalBuilderView(mode: .create(initialURL: petalSeedURL))
                .environment(feedManager)
        }
    }

    private func handleAppear() {
        if suggestedTopics.isEmpty {
            suggestedTopics = SuggestedFeedsLoader.topicsForCurrentRegion()
        }
        guard !hasInitialized else { return }
        hasInitialized = true
        urlInput = initialURL
        if !urlInput.isEmpty {
            searchFeeds()
        } else {
            isURLFieldFocused = true
        }
    }
}
