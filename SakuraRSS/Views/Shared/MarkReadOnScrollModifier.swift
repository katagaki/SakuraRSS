import SwiftUI

/// Marks an article as read the instant its top crosses above the screen.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasQueued = false
    @State private var topAtOrBelowScreenTop = true

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                if isVisible { hasBeenVisible = true }
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .global).minY >= 0
            } action: { newValue in
                if hasQueued { return }
                if topAtOrBelowScreenTop, !newValue,
                   hasBeenVisible, scrollMarkAsRead, !article.isRead {
                    hasQueued = true
                    feedManager.markReadOnScroll(article)
                    return
                }
                if topAtOrBelowScreenTop != newValue {
                    topAtOrBelowScreenTop = newValue
                }
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
