import SwiftUI

/// The article viewer's trailing toolbar actions, handed to the bottom bar.
/// Closures rather than a view: the menu's contents depend on the viewer's own
/// state, which would not follow a view snapshot rendered elsewhere.
struct BrowserArticleActions {

    struct LabelledAction {
        let title: String
        let systemImage: String
        let isEnabled: Bool
        let perform: () -> Void
    }

    var isBookmarked: Bool = false
    var toggleBookmark: (() -> Void)?
    var translate: LabelledAction?
    var summarize: LabelledAction?
    var openInApp: LabelledAction?
    var shareURL: URL?

    var isEmpty: Bool {
        toggleBookmark == nil && translate == nil && summarize == nil
            && openInApp == nil && shareURL == nil
    }
}

private struct BrowserArticleActionsReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserArticleActions?) -> Void)? = nil
}

extension EnvironmentValues {
    /// The article viewer calls this to offer its actions to the bottom bar,
    /// which is the only place they appear once the top bar is gone.
    var browserArticleActionsReporter: ((BrowserArticleActions?) -> Void)? {
        get { self[BrowserArticleActionsReporterKey.self] }
        set { self[BrowserArticleActionsReporterKey.self] = newValue }
    }
}
