import SwiftUI

/// Marks an article as read the moment it scrolls off the top of the list
/// after having been seen by the user.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasQueued = false
    @State private var lastMinY: CGFloat = .greatestFiniteMagnitude

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { newValue in
                lastMinY = newValue
            }
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                if isVisible {
                    hasBeenVisible = true
                    return
                }
                guard scrollMarkAsRead,
                      hasBeenVisible,
                      !hasQueued,
                      !article.isRead,
                      lastMinY < 120 else { return }
                hasQueued = true
                feedManager.markReadOnScroll(article)
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
