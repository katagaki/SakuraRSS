import SwiftUI
import Hanami

/// The address item: the page's name, and — when the page offers one — a mark
/// as read button sharing the same capsule. Tapping the name opens the omnibox;
/// tapping the button asks to mark the page read instead.
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

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onOpenOmnibox) {
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(
                        store.selectedTab,
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
            .contextMenu {
                BrowserPageMenu(store: store, favourites: favourites)
            }

            if let markAllRead {
                markAllReadButton(markAllRead)
            }
        }
        // Even by construction: both the icon and the glyph sit flush
        // against this padding, so neither side needs a fudge factor.
        .padding(.horizontal, 12)
        .frame(width: width > 0 ? width : nil)
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
