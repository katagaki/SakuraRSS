import SwiftUI

/// View modifier collecting the sheets and confirmation dialogs presented by `IPadSidebarView`.
struct IPadSidebarSheets: ViewModifier {

    @Environment(FeedManager.self) var feedManager

    @Binding var pendingFeedURL: String?
    @Binding var showingAddFeed: Bool
    @Binding var showingOnboarding: Bool
    @Binding var showYouTubeSafari: Bool
    @Binding var pendingYouTubeSafariURL: URL?
    @Binding var feedToDelete: Feed?
    @Binding var listToEdit: FeedList?
    @Binding var listForRules: FeedList?
    @Binding var listToDelete: FeedList?
    @Binding var onboardingCompleted: Bool

    // swiftlint:disable:next function_body_length
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddFeed) {
                pendingFeedURL = nil
            } content: {
                AddFeedView(initialURL: pendingFeedURL ?? "")
                    .environment(feedManager)
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView {
                    onboardingCompleted = true
                    ViewStyleSwitcherTip.hasCompletedOnboarding = true
                    showingOnboarding = false
                }
                .environment(feedManager)
            }
            .sheet(isPresented: $showYouTubeSafari) {
                if let url = pendingYouTubeSafariURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .confirmationDialog(
                String(localized: "FeedMenu.Delete.Title", table: "Feeds"),
                isPresented: Binding(
                    get: { feedToDelete != nil },
                    set: { if !$0 { feedToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "FeedMenu.Delete.Confirm", table: "Feeds"), role: .destructive) {
                    if let feed = feedToDelete {
                        try? feedManager.deleteFeed(feed)
                        feedToDelete = nil
                    }
                }
                Button("Shared.Cancel", role: .cancel) {
                    feedToDelete = nil
                }
            } message: {
                if let feed = feedToDelete {
                    Text(String(localized: "FeedMenu.Delete.Message.\(feed.title)", table: "Feeds"))
                }
            }
            .sheet(item: $listToEdit) { list in
                ListEditSheet(list: list)
                    .environment(feedManager)
                    .interactiveDismissDisabled()
            }
            .sheet(item: $listForRules) { list in
                ListRulesSheet(list: list)
                    .environment(feedManager)
                    .interactiveDismissDisabled()
            }
            .confirmationDialog(
                String(localized: "ListMenu.Delete.Title", table: "Lists"),
                isPresented: Binding(
                    get: { listToDelete != nil },
                    set: { if !$0 { listToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "ListMenu.Delete.Confirm", table: "Lists"), role: .destructive) {
                    if let list = listToDelete {
                        feedManager.deleteList(list)
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
    }
}

extension View {
    // swiftlint:disable:next function_parameter_count
    func iPadSidebarSheets(
        pendingFeedURL: Binding<String?>,
        showingAddFeed: Binding<Bool>,
        showingOnboarding: Binding<Bool>,
        showYouTubeSafari: Binding<Bool>,
        pendingYouTubeSafariURL: Binding<URL?>,
        feedToDelete: Binding<Feed?>,
        listToEdit: Binding<FeedList?>,
        listForRules: Binding<FeedList?>,
        listToDelete: Binding<FeedList?>,
        onboardingCompleted: Binding<Bool>
    ) -> some View {
        modifier(IPadSidebarSheets(
            pendingFeedURL: pendingFeedURL,
            showingAddFeed: showingAddFeed,
            showingOnboarding: showingOnboarding,
            showYouTubeSafari: showYouTubeSafari,
            pendingYouTubeSafariURL: pendingYouTubeSafariURL,
            feedToDelete: feedToDelete,
            listToEdit: listToEdit,
            listForRules: listForRules,
            listToDelete: listToDelete,
            onboardingCompleted: onboardingCompleted
        ))
    }
}
