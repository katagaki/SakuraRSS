import SwiftUI
import Hanami

/// Page actions, reached by pressing and holding the address capsule the way
/// Safari hides its page menu behind the same control.
struct BrowserPageMenu: View {

    @Environment(FeedManager.self) private var feedManager
    let store: BrowserTabStore
    let favourites: BrowserFavourites

    private var currentFeed: Feed? {
        BrowserLocationDescription.describe(store.selectedTab, feedManager: feedManager).feed
    }

    var body: some View {
        Group {
            if let feed = currentFeed {
                Button {
                    favourites.toggle(feed.id)
                } label: {
                    if favourites.contains(feed.id) {
                        Label(String(localized: "Menu.RemoveFromFavourites", table: "Browser"),
                              systemImage: "star.slash")
                    } else {
                        Label(String(localized: "Menu.AddToFavourites", table: "Browser"),
                              systemImage: "star")
                    }
                }
            }

            Section {
                Button {
                    store.navigate(to: .startPage)
                } label: {
                    Label(String(localized: "StartPage.Title", table: "Browser"),
                          systemImage: "square.grid.2x2")
                }
                Button {
                    store.navigate(to: .allContent)
                } label: {
                    Label(String(localized: "Location.AllContent", table: "Browser"),
                          systemImage: "tray.full")
                }
            }

            Section {
                Button {
                    store.openTab()
                } label: {
                    Label(String(localized: "Menu.NewTab", table: "Browser"),
                          systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) {
                    store.close(store.selectedTabID)
                } label: {
                    Label(String(localized: "Menu.CloseTab", table: "Browser"),
                          systemImage: "xmark.square")
                }
            }
        }
    }
}
