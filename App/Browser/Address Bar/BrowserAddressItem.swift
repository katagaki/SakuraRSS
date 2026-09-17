import SwiftUI
import Hanami

/// The page's name and, when it offers one, a mark as read button sharing the
/// same capsule.
struct BrowserAddressItem: View {

    @Environment(FeedManager.self) private var feedManager
    let store: BrowserTabStore
    let favourites: BrowserFavourites
    let width: CGFloat
    let onOpenOmnibox: () -> Void
    @State private var isConfirmingMarkAllRead = false

    private var markAllRead: BrowserMarkAllReadAction? {
        store.markAllReadActions[store.selectedTabID]
    }

    private var articleActions: BrowserArticleActions? {
        store.articleActions[store.selectedTabID]
    }

    private var bookmarksActions: BrowserBookmarksActions? {
        store.bookmarksActions[store.selectedTabID]
    }

    /// What the trailing slot holds. Animating on the actions themselves would
    /// restart the fade every time a page republishes an unchanged menu.
    private var trailingSlot: BrowserAddressTrailingSlot {
        if articleActions != nil {
            .article
        } else if bookmarksActions != nil {
            .bookmarks
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
                        store.displayedTab,
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
            } else if let markAllRead {
                markAllReadButton(markAllRead)
                    .transition(.opacity)
            }
        }
        .animation(BrowserLocationLabel.contentChange, value: trailingSlot)
        // Even by construction: both the icon and the glyph sit flush
        // against this padding, so neither side needs a fudge factor.
        .padding(.horizontal, 12)
        // A toolbar item is proposed its ideal size, so `maxWidth: .infinity`
        // resolves to the content width and the bar collapses around a short
        // page name. The measured width is what makes it fill.
        .frame(width: width > 0 ? width : nil)
        // The item widens by the back button's slot at a tab's root, and that
        // lands on the same navigation as the label swap.
        .animation(BrowserLocationLabel.contentChange, value: width)
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
