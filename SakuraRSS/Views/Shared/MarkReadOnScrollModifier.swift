import SwiftUI

/// Marks an article as read the instant the row's top crosses above the
/// top of the screen after the user has seen it.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasQueued = false
    @State private var lastMinY: CGFloat = .greatestFiniteMagnitude

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                if isVisible { hasBeenVisible = true }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { newValue in
                if !hasQueued,
                   hasBeenVisible,
                   scrollMarkAsRead,
                   !article.isRead,
                   lastMinY >= 0,
                   newValue < 0 {
                    hasQueued = true
                    feedManager.markReadOnScroll(article)
                }
                lastMinY = newValue
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
