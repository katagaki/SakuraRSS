import SwiftUI
import Hanami

/// iPad, Mac and Vision chrome: a tab strip and address field above the page,
/// the way Safari lays itself out when there is room for both.
struct BrowserRegularShell: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    @Environment(\.browserBookmarksAction) private var openBookmarks
    @Environment(\.browserOmniboxAction) private var openOmnibox

    var body: some View {
        VStack(spacing: 0) {
            BrowserTopTabBar()
            addressRow
            Divider()
            BrowserTabStack()
        }
        .background(.background.secondary)
    }

    private var addressRow: some View {
        HStack(spacing: 8) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!store.selectedTab.canGoBack)
            .accessibilityLabel(String(localized: "AddressBar.Back", table: "Browser"))

            BrowserAddressCapsule(tab: store.selectedTab) {
                openOmnibox?()
            }
            .frame(maxWidth: 560)
            .compatibleGlassEffect(in: .capsule, interactive: true)
            .contextMenu {
                BrowserPageMenu(store: store, favourites: favourites)
            }

            Button {
                openBookmarks?()
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 15))
                    .frame(width: 30, height: 30)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Location.Bookmarks", table: "Browser"))

            Menu {
                BrowserPageMenu(store: store, favourites: favourites)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .frame(width: 30, height: 30)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
