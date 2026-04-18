import SwiftUI

/// Marks an article as read once it has been visible and then scrolled out of
/// view. Enabled only when the user has opted in via the
/// `Display.ScrollMarkAsRead` setting.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasScrolledPastTop = false

    private var latestIsRead: Bool {
        feedManager.article(byID: article.id)?.isRead ?? article.isRead
    }

    func body(content: Content) -> some View {
        content
            // Track only the boolean transition of crossing the viewport's top
            // edge. `onGeometryChange` diffs the observed value, so `action`
            // fires only when the boolean flips (instead of on every scroll
            // frame when we were observing `minY` directly).
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .global).minY < 0
            } action: { newValue in
                hasScrolledPastTop = newValue
            }
            .onAppear {
                hasBeenVisible = true
                if article.isRead != latestIsRead {
                    #if DEBUG
                    debugPrint("[ScrollMarkAsRead] Stale read state on appear for \(article.id), reloading")
                    #endif
                    Task { await feedManager.loadFromDatabaseInBackground() }
                }
            }
            .onDisappear {
                guard scrollMarkAsRead, hasBeenVisible, !latestIsRead else { return }
                // Only mark as read when the row scrolled off the TOP of the
                // viewport (user scrolled down past it). When the top edge is
                // above the screen's origin the transform above sets
                // `hasScrolledPastTop` to true.
                guard hasScrolledPastTop else { return }
                #if DEBUG
                debugPrint("[ScrollMarkAsRead] Marking article as read: \(article.id) - \(article.title)")
                #endif
                let articleID = article.id
                Task { @MainActor in
                    guard let fresh = feedManager.article(byID: articleID), !fresh.isRead else {
                        return
                    }
                    feedManager.markReadDebounced(fresh)
                }
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
