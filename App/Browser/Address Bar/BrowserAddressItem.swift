import EnhancedNavigation
import SwiftUI
import Hanami

/// The page's name and, when it offers one, a mark as read button sharing the
/// same capsule.
struct BrowserAddressItem: View {

    @Environment(FeedManager.self) private var feedManager
    let store: BrowserTabStore
    let slots: BrowserPageSlots
    let tabID: UUID
    let favourites: BrowserFavourites
    let onOpenOmnibox: () -> Void
    @State private var isConfirmingMarkAllRead = false

    /// A page below the visible one re-reports itself as a pop reveals its
    /// neighbour, so a slot only counts while it belongs to the page the bar
    /// is naming.
    private var pageToken: BrowserPathToken? {
        store.displayedPathToken(for: tabID)
    }

    private var markAllRead: BrowserMarkAllReadAction? {
        slots.markAllReadActions[tabID]?.value(forPageAt: pageToken)
    }

    private var articleActions: BrowserArticleActions? {
        slots.articleActions[tabID]?.value(forPageAt: pageToken)
    }

    private var bookmarksActions: BrowserBookmarksActions? {
        slots.bookmarksActions[tabID]?.value(forPageAt: pageToken)
    }

    private var followingActions: BrowserFollowingActions? {
        slots.followingActions[tabID]?.value(forPageAt: pageToken)
    }

    private var startPageActions: BrowserStartPageActions? {
        slots.startPageActions[tabID]?.value(forPageAt: pageToken)
    }

    private var displayStyleOptions: BrowserDisplayStyleOptions? {
        slots.displayStyleOptions[tabID]?.value(forPageAt: pageToken)
    }

    /// What the trailing slot holds. Animating on the actions themselves would
    /// restart the fade every time a page republishes an unchanged menu.
    private var trailingSlot: BrowserAddressTrailingSlot {
        if articleActions != nil {
            .article
        } else if bookmarksActions != nil {
            .bookmarks
        } else if followingActions != nil {
            .following
        } else if startPageActions != nil {
            .startPage
        } else if displayStyleOptions != nil {
            .displayStyle
        } else if markAllRead != nil {
            .markAllRead
        } else {
            .none
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onOpenOmnibox) {
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(
                        store.displayedTab(for: tabID),
                        feedManager: feedManager
                    ),
                    iconSize: 24,
                    titleFont: .subheadline,
                    showsSubtitle: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if let articleActions {
                articleMenu(articleActions)
                    .transition(.opacity)
            } else if let bookmarksActions {
                BrowserBookmarksMenu(actions: bookmarksActions)
                    .transition(.opacity)
            } else if let followingActions {
                BrowserFollowingMenu(actions: followingActions)
                    .transition(.opacity)
            } else if let startPageActions {
                BrowserStartPageMenu(actions: startPageActions)
                    .transition(.opacity)
            } else if let displayStyleOptions {
                BrowserPageDisplayMenu(options: displayStyleOptions, markAllRead: markAllRead)
                    .transition(.opacity)
            } else if let markAllRead {
                markAllReadButton(markAllRead)
                    .transition(.opacity)
            }
        }
        .animation(BrowserLocationLabel.contentChange, value: trailingSlot)
        // Even by construction: both the icon and the glyph sit flush
        // against this padding, so neither side needs a fudge factor. As far
        // in from the capsule's ends as a `.bottomBar` item's content sat.
        .padding(.horizontal, 17)
        .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
        // Behind the label rather than over the page: the browser has no
        // room for Home's refresh pill, so the bar itself reports the work.
        .background {
            BrowserAddressProgressBackground(progress: slots.displayedProgress(for: tabID, in: store))
        }
        .animation(.smooth, value: slots.displayedProgress(for: tabID, in: store) == nil)
    }

    /// The article viewer's trailing actions, in the slot mark as read uses
    /// on a list. A page is one or the other, never both.
    private func articleMenu(_ actions: BrowserArticleActions) -> some View {
        Menu {
            if let toggleBookmark = actions.toggleBookmark {
                Button(action: toggleBookmark) {
                    Label(
                        String(localized: actions.isBookmarked
                               ? "Article.RemoveBookmark" : "Article.Bookmark",
                               table: "Articles"),
                        systemImage: actions.isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
            }

            if actions.translate != nil || actions.summarize != nil {
                Divider()
                if let translate = actions.translate {
                    menuButton(translate)
                }
                if let summarize = actions.summarize {
                    menuButton(summarize)
                }
            }

            if let openInApp = actions.openInApp {
                Divider()
                menuButton(openInApp)
            }

            if let shareURL = actions.shareURL {
                Divider()
                ShareLink(item: shareURL) {
                    Label(String(localized: "Article.Share", table: "Articles"),
                          systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17))
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
    }

    private func menuButton(_ action: BrowserArticleActions.LabelledAction) -> some View {
        Button(action: action.perform) {
            Label(action.title, systemImage: action.systemImage)
        }
        .disabled(!action.isEnabled)
    }

    private func markAllReadButton(_ action: BrowserMarkAllReadAction) -> some View {
        Button {
            isConfirmingMarkAllRead = true
        } label: {
            Image(systemName: "envelope.open")
                .font(.system(size: 17))
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "MarkAllRead", table: "Articles"))
        .popover(isPresented: $isConfirmingMarkAllRead) {
            VStack(spacing: 12) {
                Text(String(localized: "MarkAllRead.Confirm", table: "Articles"))
                    .font(.body)
                Button {
                    isConfirmingMarkAllRead = false
                    Task { @MainActor in action.perform() }
                } label: {
                    Text(String(localized: "MarkAllRead", table: "Articles"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .presentationCompactAdaptation(.popover)
        }
    }
}
