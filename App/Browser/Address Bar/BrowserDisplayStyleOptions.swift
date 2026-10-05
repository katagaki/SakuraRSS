import SwiftUI
import Hanami

/// A content list's display style, for its omnibox menu, since the top bar's
/// own menu is gone in the browser.
struct BrowserDisplayStyleOptions {

    var displayStyle: Binding<FeedDisplayStyle>
    var hasImages: Bool
    var showsTimeline: Bool = true
    var showsVideo: Bool = true
    var showsPodcast: Bool = false
    var showsCards: Bool = true
    var showsScroll: Bool = true
}
