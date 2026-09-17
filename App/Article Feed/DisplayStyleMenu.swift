import SwiftUI
import Hanami

/// The display style options as a submenu, for the ellipsis menus that keep
/// their top level to one row per action.
struct DisplayStyleMenu: View {

    @Binding var displayStyle: FeedDisplayStyle
    let hasImages: Bool
    var showTimeline: Bool = true
    var showVideo: Bool = true
    var showPodcast: Bool = false
    var showCards: Bool = true
    var showScroll: Bool = true

    var body: some View {
        Menu {
            DisplayStylePicker(
                displayStyle: $displayStyle,
                hasImages: hasImages,
                showTimeline: showTimeline,
                showVideo: showVideo,
                showPodcast: showPodcast,
                showCards: showCards,
                showScroll: showScroll
            )
        } label: {
            Label(String(localized: "DisplayStyle", table: "Articles"),
                  systemImage: "square.grid.2x2")
        }
        .menuActionDismissBehavior(.disabled)
    }
}
