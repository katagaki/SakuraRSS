import SwiftUI

/// Marks an article as read once the user has seen it on screen and then
/// scrolled it past the top of the list. Driven by the
/// `Display.ScrollMarkAsRead` setting.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var isPastTop = false
    @State private var hasQueued = false

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .global).minY < 0
            } action: { newValue in
                isPastTop = newValue
            }
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                if isVisible {
                    hasBeenVisible = true
                    return
                }
                guard scrollMarkAsRead,
                      hasBeenVisible,
                      isPastTop,
                      !hasQueued,
                      !article.isRead else { return }
                hasQueued = true
                feedManager.markReadDebounced(article)
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
