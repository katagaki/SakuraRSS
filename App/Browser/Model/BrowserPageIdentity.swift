import SwiftUI

/// What the visible page calls itself. Pages report this upward because a
/// `NavigationPath` is opaque once the existing `NavigationLink(value:)` call
/// sites elsewhere in the app have pushed into it.
struct BrowserPageIdentity: Equatable, Codable {
    var title: String
    var subtitle: String?
    var symbolName: String
    var feedID: Int64?
    /// Set by a search page, so tapping the bar reopens with the same term
    /// rather than an empty field.
    var searchQuery: String?
    /// How to push this page again after a relaunch. Nil for a tab's root,
    /// which is restored from its location instead.
    var pathToken: BrowserPathToken?
}

extension BrowserPageIdentity {
    /// Whether two reports are the same page. A page on its way out re-reports
    /// itself as the stack pops, by which point its path token has already
    /// unwound to the root's, so the name is what tells the two apart.
    func names(_ other: BrowserPageIdentity) -> Bool {
        if let pathToken, let otherPathToken = other.pathToken {
            return pathToken == otherPathToken
        }
        return title == other.title && symbolName == other.symbolName && feedID == other.feedID
    }
}

private struct BrowserPageReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserPageIdentity) -> Void)? = nil
}

extension EnvironmentValues {
    var browserPageReporter: ((BrowserPageIdentity) -> Void)? {
        get { self[BrowserPageReporterKey.self] }
        set { self[BrowserPageReporterKey.self] = newValue }
    }
}

private struct BrowserPageModifier: ViewModifier {

    @Environment(\.browserPageReporter) private var reporter
    @Environment(\.browserPathToken) private var pathToken
    @Environment(\.browserPageSlotReporter) private var slotReporter
    let identity: BrowserPageIdentity

    private var reported: BrowserPageIdentity {
        var identity = self.identity
        identity.pathToken = pathToken
        return identity
    }

    func body(content: Content) -> some View {
        content
            .environment(\.browserMarkAllReadReporter) { report(.markAllRead($0)) }
            .environment(\.browserArticleActionsReporter) { report(.article($0)) }
            .environment(\.browserBookmarksActionsReporter) { report(.bookmarks($0)) }
            .environment(\.browserFollowingActionsReporter) { report(.following($0)) }
            .environment(\.browserStartPageActionsReporter) { report(.startPage($0)) }
            .environment(\.browserDisplayStyleReporter) { report(.displayStyle($0)) }
            .environment(\.browserPageProgressReporter) { report(.progress($0)) }
            .onAppear { reporter?(reported) }
            .onChange(of: reported) { reporter?(reported) }
    }

    private func report(_ slot: BrowserPageSlotReport) {
        slotReporter?(slot, pathToken)
    }
}

extension View {
    /// Reports the page's label to the browser shell. Popping back re-appears
    /// the revealed page, which re-reports and keeps the address bar honest.
    func browserPage(
        title: String,
        subtitle: String? = nil,
        symbolName: String,
        feedID: Int64? = nil,
        searchQuery: String? = nil
    ) -> some View {
        modifier(BrowserPageModifier(identity: BrowserPageIdentity(
            title: title,
            subtitle: subtitle,
            symbolName: symbolName,
            feedID: feedID,
            searchQuery: searchQuery
        )))
    }
}
