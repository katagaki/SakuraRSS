import SwiftUI
import Hanami

extension FollowingPage {

    /// Under browser chrome these same controls live in the bottom bar's
    /// menu instead, so the top bar contributes nothing.
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        if !isBrowserChromeActive {
            topBarContent
        }
    }

    @ToolbarContentBuilder
    private var topBarContent: some ToolbarContent {
        if !isEditingFeeds {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(String(localized: "FeedList.Edit", table: "Feeds"),
                       systemImage: "pencil") {
                    isEditingFeeds = true
                }
                .labelStyle(.iconOnly)
                .disabled(feedManager.feeds.isEmpty)
                Button {
                    isPresentingNewListSheet = true
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .accessibilityLabel(String(localized: "Section.Lists.NewList", table: "Settings"))
                .matchedTransitionSource(id: "newList", in: newListNamespace)
            }
            #if !os(visionOS)
            ToolbarSpacer(.flexible, placement: .topBarTrailing)
            #endif
        }
        if isSelectingFeeds && !selectedFeedIDs.isEmpty {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isPresentingBulkDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel(String(localized: "FeedList.Selection.Delete", table: "Feeds"))
                Button {
                    isPresentingBulkEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(String(localized: "FeedList.Selection.Edit", table: "Feeds"))
            }
            #if !os(visionOS)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            #endif
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isEditingFeeds {
                if isSelectingFeeds {
                    Button(role: .cancel) {
                        toggleSelectMode()
                    }
                } else {
                    Button {
                        toggleSelectMode()
                    } label: {
                        Text(String(localized: "FeedList.Select", table: "Feeds"))
                    }
                    Button(role: .confirm) {
                        exitEditMode()
                    }
                }
            } else {
                Button {
                    isPresentingAddFeedSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .compatibleGlassProminentButtonStyle()
                .matchedTransitionSource(id: "addFeed", in: addFeedNamespace)
            }
        }
    }

    @ViewBuilder
    var emptyStateOverlay: some View {
        if feedManager.feeds.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "FeedList.Empty.Title", table: "Feeds"),
                      systemImage: "newspaper")
            } description: {
                Text(String(localized: "FeedList.Empty.Description", table: "Feeds"))
            } actions: {
                Button(String(localized: "FeedList.Empty.AddFeed", table: "Feeds")) {
                    isPresentingAddFeedSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
