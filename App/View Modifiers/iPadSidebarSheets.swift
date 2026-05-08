import SwiftUI

// swiftlint:disable:next type_name
struct iPadSidebarSheetsModifier: ViewModifier {

    @Environment(FeedManager.self) var feedManager

    let bindings: iPadSidebarSheetsBindings

    func body(content: Content) -> some View {
        content
            .modifier(IPadSidebarSheetsPresentationModifier(bindings: bindings))
            .modifier(IPadSidebarSheetsConfirmationModifier(bindings: bindings))
    }
}

private struct IPadSidebarSheetsPresentationModifier: ViewModifier {

    @Environment(FeedManager.self) var feedManager
    let bindings: iPadSidebarSheetsBindings

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: bindings.showingAddFeed) {
                bindings.pendingFeedURL.wrappedValue = nil
            } content: {
                AddFeedView(initialURL: bindings.pendingFeedURL.wrappedValue ?? "")
                    .environment(feedManager)
            }
            .sheet(isPresented: bindings.showingOnboarding) {
                OnboardingView {
                    bindings.onboardingCompleted.wrappedValue = true
                    ViewStyleSwitcherTip.hasCompletedOnboarding = true
                    bindings.showingOnboarding.wrappedValue = false
                }
                .environment(feedManager)
            }
            .sheet(isPresented: bindings.showYouTubeSafari) {
                if let url = bindings.pendingYouTubeSafariURL.wrappedValue {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: bindings.showingWeatherLocationPicker) {
                TodayWeatherLocationSheet()
                    .presentationDetents([.large])
            }
            .sheet(item: bindings.listToEdit) { list in
                ListEditSheet(list: list)
                    .environment(feedManager)
                    .interactiveDismissDisabled()
            }
            .sheet(item: bindings.listForRules) { list in
                ListRulesSheet(list: list)
                    .environment(feedManager)
                    .interactiveDismissDisabled()
            }
    }
}

private struct IPadSidebarSheetsConfirmationModifier: ViewModifier {

    @Environment(FeedManager.self) var feedManager
    let bindings: iPadSidebarSheetsBindings

    func body(content: Content) -> some View {
        content
            .modifier(IPadSidebarFeedDeletionConfirmation(
                feedToDelete: bindings.feedToDelete
            ))
            .modifier(IPadSidebarListDeletionConfirmation(
                listToDelete: bindings.listToDelete
            ))
    }
}

private struct IPadSidebarFeedDeletionConfirmation: ViewModifier {

    @Environment(FeedManager.self) var feedManager
    let feedToDelete: Binding<Feed?>

    func body(content: Content) -> some View {
        content.confirmationDialog(
            String(localized: "FeedMenu.Unfollow.Title", table: "Feeds"),
            isPresented: Binding(
                get: { feedToDelete.wrappedValue != nil },
                set: { if !$0 { feedToDelete.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"),
                role: .destructive
            ) {
                if let feed = feedToDelete.wrappedValue {
                    try? feedManager.deleteFeed(feed)
                    feedToDelete.wrappedValue = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                feedToDelete.wrappedValue = nil
            }
        } message: {
            if let feed = feedToDelete.wrappedValue {
                Text(String(localized: "FeedMenu.Unfollow.Message.\(feed.title)", table: "Feeds"))
            }
        }
    }
}

private struct IPadSidebarListDeletionConfirmation: ViewModifier {

    @Environment(FeedManager.self) var feedManager
    let listToDelete: Binding<FeedList?>

    func body(content: Content) -> some View {
        content.confirmationDialog(
            String(localized: "ListMenu.Delete.Title", table: "Lists"),
            isPresented: Binding(
                get: { listToDelete.wrappedValue != nil },
                set: { if !$0 { listToDelete.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "ListMenu.Delete.Confirm", table: "Lists"),
                role: .destructive
            ) {
                if let list = listToDelete.wrappedValue {
                    feedManager.deleteList(list)
                    listToDelete.wrappedValue = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                listToDelete.wrappedValue = nil
            }
        } message: {
            if let list = listToDelete.wrappedValue {
                Text(String(localized: "ListMenu.Delete.Message.\(list.name)", table: "Lists"))
            }
        }
    }
}

extension View {
    func iPadSidebarSheets(bindings: iPadSidebarSheetsBindings) -> some View {
        modifier(iPadSidebarSheetsModifier(bindings: bindings))
    }
}
