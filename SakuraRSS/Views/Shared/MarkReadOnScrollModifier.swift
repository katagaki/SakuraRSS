import SwiftUI

/// Marks an article as read once it has been visible and then scrolled out of
/// view. Enabled only when the user has opted in via the
/// `Display.ScrollMarkAsRead` setting.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false

    private var latestIsRead: Bool {
        feedManager.article(byID: article.id)?.isRead ?? article.isRead
    }

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                guard scrollMarkAsRead else { return }
                if isVisible {
                    hasBeenVisible = true
                } else if hasBeenVisible, !latestIsRead {
                    #if DEBUG
                    debugPrint("[ScrollMarkAsRead] Marking article as read: \(article.id) — \(article.title)")
                    #endif
                    let articleID = article.id
                    Task { @MainActor in
                        guard let fresh = feedManager.article(byID: articleID), !fresh.isRead else {
                            return
                        }
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.markRead(fresh)
                        }
                    }
                }
            }
            .onAppear {
                if article.isRead != latestIsRead {
                    #if DEBUG
                    debugPrint("[ScrollMarkAsRead] Stale read state on appear for \(article.id), reloading")
                    #endif
                    feedManager.loadFromDatabase()
                }
            }
    }
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
