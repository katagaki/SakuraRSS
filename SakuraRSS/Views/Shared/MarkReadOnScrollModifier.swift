import SwiftUI

/// Marks an article as read once the user has seen it on screen and then
/// scrolled it past the top of the list.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var isVisibleNow = false
    @State private var isPastTop = false
    @State private var hasQueued = false

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .global).minY < 0
            } action: { newValue in
                isPastTop = newValue
                if newValue {
                    tryQueueRead()
                }
            }
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                isVisibleNow = isVisible
                if isVisible {
                    hasBeenVisible = true
                } else {
                    tryQueueRead()
                }
            }
    }

    /// Driven from both callbacks so whichever of the visibility and
    /// geometry updates lands second commits the queue.
    private func tryQueueRead() {
        guard scrollMarkAsRead,
              hasBeenVisible,
              isPastTop,
              !isVisibleNow,
              !hasQueued,
              !article.isRead else { return }
        hasQueued = true
        feedManager.markReadDebounced(article)
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
