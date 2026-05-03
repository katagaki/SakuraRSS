import SwiftUI

struct IPadSidebarView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false

    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?

    @SceneStorage("IPadSidebar.SelectedDestinationToken")
    private var selectedDestinationToken: String = SidebarDestination.today.persistenceToken

    @State var selectedDestination: SidebarDestination? = .today
    @State var selectedArticle: Article?
    @State var ephemeralDestinations: [EphemeralArticleDestination] = []
    @State private var hasRestoredSelectedDestination: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State var showingAddFeed = false
    @State var showingNewList = false
    @State var showingMore = false
    @State private var showingOnboarding = false
    @State var showYouTubeSafari = false
    @State var pendingYouTubeSafariURL: URL?
    @State var searchText = ""

    @State var feedForEditSheet: FeedIDIdentifier?
    @State var feedToDelete: Feed?
    @State var listToEdit: FeedList?
    @State var listForRules: FeedList?
    @State var listToDelete: FeedList?

    @Namespace var cardZoom

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            IPadSidebarList(
                selectedDestination: $selectedDestination,
                searchText: $searchText,
                feedForEditSheet: $feedForEditSheet,
                feedToDelete: $feedToDelete,
                listToEdit: $listToEdit,
                listForRules: $listForRules,
                listToDelete: $listToDelete,
                showingMore: $showingMore,
                showingAddFeed: $showingAddFeed,
                showingNewList: $showingNewList,
                availableSections: availableSections,
                sectionIcon: sectionIcon,
                onDestinationChanged: {
                    selectedArticle = nil
                    ephemeralDestinations = []
                }
            )
        } content: {
            contentColumn
        } detail: {
            detailContent
        }
        .iPadSidebarSheets(
            pendingFeedURL: $pendingFeedURL,
            showingAddFeed: $showingAddFeed,
            showingOnboarding: $showingOnboarding,
            showYouTubeSafari: $showYouTubeSafari,
            pendingYouTubeSafariURL: $pendingYouTubeSafariURL,
            feedToDelete: $feedToDelete,
            listToEdit: $listToEdit,
            listForRules: $listForRules,
            listToDelete: $listToDelete,
            onboardingCompleted: $onboardingCompleted
        )
        .onChange(of: pendingFeedURL) {
            if pendingFeedURL != nil {
                showingAddFeed = true
            }
        }
        .onChange(of: pendingArticleID) {
            if let articleID = pendingArticleID {
                handlePendingArticle(articleID)
            }
        }
        .onChange(of: pendingOpenRequest) {
            if let request = pendingOpenRequest {
                handlePendingOpenRequest(request)
            }
        }
        .task {
            if let request = pendingOpenRequest {
                handlePendingOpenRequest(request)
            }
        }
        .onAppear {
            if !hasRestoredSelectedDestination {
                hasRestoredSelectedDestination = true
                if let restored = SidebarDestination.resolve(
                    token: selectedDestinationToken,
                    feedManager: feedManager
                ), restored != selectedDestination {
                    selectedDestination = restored
                }
            }
            if !onboardingCompleted {
                showingOnboarding = true
            }
        }
        .onChange(of: selectedDestination) { _, newValue in
            guard hasRestoredSelectedDestination,
                  let newValue, newValue != .more else { return }
            selectedDestinationToken = newValue.persistenceToken
        }
    }
}
