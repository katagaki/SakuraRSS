import SwiftUI
import Hanami

/// A content list's own actions: the display style, and marking everything
/// read when the page offers it.
struct BrowserPageDisplayMenu: View {

    let options: BrowserDisplayStyleOptions
    var markAllRead: (() -> Void)?

    var body: some View {
        Menu {
            DisplayStyleMenu(
                displayStyle: options.displayStyle,
                hasImages: options.hasImages,
                showTimeline: options.showsTimeline,
                showVideo: options.showsVideo,
                showPodcast: options.showsPodcast,
                showCards: options.showsCards,
                showScroll: options.showsScroll
            )
            if let markAllRead {
                Section {
                    Button {
                        Task { @MainActor in markAllRead() }
                    } label: {
                        Label(String(localized: "MarkAllRead", table: "Articles"),
                              systemImage: "envelope.open")
                    }
                }
            }
        } label: {
            Label(String(localized: "Tabs.More"), systemImage: "ellipsis")
        }
    }
}
