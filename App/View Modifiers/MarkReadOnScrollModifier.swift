import SwiftUI
import Hanami

/// Marks an article as read the instant its top crosses above the screen.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var storedScrollMarkAsRead: Bool = false
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false

    private var scrollMarkAsRead: Bool {
        DoomscrollingMode.effectiveScrollMarkAsRead(storedScrollMarkAsRead)
    }

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasQueued = false
    @State private var topAtOrBelowScreenTop = true

    // Only install the per-row geometry/visibility observers when the feature is
    // active. Attaching them to every row unconditionally drives continuous
    // layout callbacks across the whole list while scrolling, even when the
    // default (disabled) setting means the work is always discarded.
    @ViewBuilder
    func body(content: Content) -> some View {
        if scrollMarkAsRead {
            content
                .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                    if isVisible { hasBeenVisible = true }
                }
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.frame(in: .global).minY >= 0
                } action: { newValue in
                    if hasQueued { return }
                    if topAtOrBelowScreenTop, !newValue,
                       hasBeenVisible, !article.isRead {
                        hasQueued = true
                        feedManager.markReadOnScroll(article)
                        return
                    }
                    if topAtOrBelowScreenTop != newValue {
                        topAtOrBelowScreenTop = newValue
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
