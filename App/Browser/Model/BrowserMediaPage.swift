import EnhancedNavigation
import SwiftUI

private struct BrowserMediaPageModifier: ViewModifier {

    @Environment(BrowserTabStore.self) private var store: BrowserTabStore?
    @Environment(\.browserTabID) private var tabID
    @Environment(\.browserPathToken) private var pathToken
    let ownsMedia: @MainActor () -> Bool
    let stop: @MainActor () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let store, let tabID, let pathToken else { return }
                store.registerMediaPage(
                    pathToken,
                    in: tabID,
                    ownsMedia: ownsMedia,
                    stop: stop
                )
            }
    }
}

extension View {
    /// Stops the page's media once it is popped or its tab is closed. Being
    /// covered, hidden behind another tab, or evicted leaves it playing.
    func browserMediaPage(
        ownsMedia: @escaping @MainActor () -> Bool,
        stop: @escaping @MainActor () -> Void
    ) -> some View {
        modifier(BrowserMediaPageModifier(ownsMedia: ownsMedia, stop: stop))
    }
}
