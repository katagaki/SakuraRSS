import SwiftUI
import Hanami

/// Prototype Safari-style shell: tabs, one omnibox that both searches and
/// subscribes, and a start page. Enabled from Browsing settings.
struct BrowserView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var store = BrowserTabStore.restored()
    @State private var favourites = BrowserFavourites()
    @State private var isShowingOmnibox = false
    @State private var pendingAddFeedURL: String?
    @State private var addFeedSession = AddFeedSession()

    @Binding var pendingFeedURL: String?

    private var layout: BrowserLayout {
        BrowserLayout.resolve(horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        ZStack {
            shell
            if isShowingOmnibox {
                BrowserOmniboxView(
                    store: store,
                    isPresented: $isShowingOmnibox,
                    pendingAddFeedURL: $pendingAddFeedURL
                )
                .transition(.opacity)
            }
        }
        .environment(store)
        .environment(favourites)
        .environment(\.browserLayout, layout)
        .environment(\.browserOmniboxAction) {
            withAnimation(.smooth.speed(2.0)) {
                isShowingOmnibox = true
            }
        }
        .sheet(isPresented: addFeedBinding) {
            AddFeedView(initialURL: pendingAddFeedURL ?? "", session: addFeedSession)
                .environment(feedManager)
        }
        .onChange(of: pendingFeedURL) {
            if let url = pendingFeedURL {
                pendingAddFeedURL = url
                pendingFeedURL = nil
            }
        }
    }

    @ViewBuilder
    private var shell: some View {
        switch layout {
        case .compact:
            BrowserCompactShell()
        case .regular:
            BrowserRegularShell(isShowingOmnibox: $isShowingOmnibox)
        }
    }

    private var addFeedBinding: Binding<Bool> {
        Binding(
            get: { pendingAddFeedURL != nil },
            set: { isPresented in
                if !isPresented { pendingAddFeedURL = nil }
            }
        )
    }
}
