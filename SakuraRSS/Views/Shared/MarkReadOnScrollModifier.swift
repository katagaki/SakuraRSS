import SwiftUI

/// Marks an article as read once it scrolls off screen after having been
/// seen by the user.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasQueued = false

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                if isVisible {
                    hasBeenVisible = true
                    return
                }
                guard scrollMarkAsRead,
                      hasBeenVisible,
                      !hasQueued,
                      !article.isRead else { return }
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
