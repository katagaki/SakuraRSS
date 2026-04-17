import SwiftUI

/// Marks an article as read once it has been visible and then scrolled out of
/// view. Enabled only when the user has opted in via the
/// `Display.ScrollMarkAsRead` setting.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                guard scrollMarkAsRead else { return }
                if isVisible {
                    hasBeenVisible = true
                } else if hasBeenVisible, !article.isRead {
                    #if DEBUG
                    debugPrint("[ScrollMarkAsRead] Marking article as read: \(article.id) — \(article.title)")
                    #endif
                    let articleToMark = article
                    Task { @MainActor in
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.markRead(articleToMark)
                        }
                    }
                }
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
