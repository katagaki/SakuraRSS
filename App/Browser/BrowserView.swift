import SwiftUI
import Hanami

/// Prototype Safari-style shell: tabs, one omnibox that both searches and
/// subscribes, and a start page. Enabled from Browsing settings.
struct BrowserView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var store = BrowserTabStore.restored()
    @State private var favourites = BrowserFavourites()
    @State private var omnibox = BrowserOmniboxModel()
    @State private var presentedSheet: BrowserSheetKind?
    @State private var pendingAddFeedURL: String?
    @State private var addFeedSession = AddFeedSession()

    @Binding var pendingFeedURL: String?

    private var layout: BrowserLayout {
        BrowserLayout.resolve(horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        shell
        .environment(store)
        .environment(favourites)
        .environment(\.browserLayout, layout)
        .environment(\.browserBookmarksAction) {
            presentedSheet = .bookmarks
        }
        .environment(omnibox)
        .environment(\.browserAddFeedAction) { url in
            pendingAddFeedURL = url
        }
        .environment(\.browserOmniboxAction) {
            withAnimation(.smooth.speed(2.0)) {
                omnibox.activate()
            }
        }
        .environment(\.browserOmniboxSubmit) {
            submitOmnibox()
        }
        .animation(.smooth.speed(2.0), value: omnibox.isActive)
        .sheet(
            item: $presentedSheet,
            onDismiss: { pendingAddFeedURL = nil },
            content: { sheet in
                switch sheet {
                case .bookmarks:
                    BrowserBookmarksSheet()
                        .environment(feedManager)
                case .addFeed(let url):
                    AddFeedView(initialURL: url, session: addFeedSession)
                        .environment(feedManager)
                }
            }
        )
        .onChange(of: pendingAddFeedURL) {
            if let url = pendingAddFeedURL {
                presentedSheet = .addFeed(url: url)
            }
        }
        .onChange(of: pendingFeedURL) {
            if let url = pendingFeedURL {
                pendingAddFeedURL = url
                pendingFeedURL = nil
            }
        }
    }

    private func submitOmnibox() {
        let trimmed = omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let urlString = BrowserAddressInput.normalizedURLString(from: trimmed) {
            pendingAddFeedURL = urlString
        } else {
            store.navigate(to: .search(trimmed))
        }
        omnibox.deactivate()
    }

    @ViewBuilder
    private var shell: some View {
        switch layout {
        case .compact:
            BrowserCompactShell()
        case .regular:
            BrowserRegularShell()
        }
    }

}
