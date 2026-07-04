#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct OpenFeedInNewWindowButton: View {

    @Environment(\.openWindow) private var openWindow
    let feed: Feed

    var body: some View {
        Button {
            openWindow(id: "FeedWindow", value: feed.id)
        } label: {
            Label(
                String(localized: "Feed.OpenInNewWindow", table: "Feeds"),
                systemImage: "macwindow.badge.plus"
            )
        }
    }
}
#endif
