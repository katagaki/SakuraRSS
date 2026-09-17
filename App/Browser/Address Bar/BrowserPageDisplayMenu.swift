import SwiftUI
import Hanami

/// A content list's own actions: the display style, and marking everything
/// read when the page offers it.
struct BrowserPageDisplayMenu: View {

    let options: BrowserDisplayStyleOptions
    let markAllRead: BrowserMarkAllReadAction?

    var body: some View {
        Menu {
            DisplayStylePicker(
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
                        Task { @MainActor in markAllRead.perform() }
                    } label: {
                        Label(String(localized: "MarkAllRead", table: "Articles"),
                              systemImage: "envelope.open")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17))
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
    }
}
