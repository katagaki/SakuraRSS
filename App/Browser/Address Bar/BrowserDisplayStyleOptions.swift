import SwiftUI
import Hanami

/// A content list's display style, handed to the address bar so the browser's
/// ellipsis menu can change it once the top bar's own menu is gone.
struct BrowserDisplayStyleOptions {

    var displayStyle: Binding<FeedDisplayStyle>
    var hasImages: Bool
    var showsTimeline: Bool = true
    var showsVideo: Bool = true
    var showsPodcast: Bool = false
    var showsCards: Bool = true
    var showsScroll: Bool = true
}

private struct BrowserDisplayStyleReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserDisplayStyleOptions?) -> Void)? = nil
}

extension EnvironmentValues {
    /// Content lists call this to offer their display style to the address bar.
    var browserDisplayStyleReporter: ((BrowserDisplayStyleOptions?) -> Void)? {
        get { self[BrowserDisplayStyleReporterKey.self] }
        set { self[BrowserDisplayStyleReporterKey.self] = newValue }
    }
}
