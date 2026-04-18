import SwiftUI

/// Marks an article as read once it has been visible and then scrolled out of
/// view. Enabled only when the user has opted in via the
/// `Display.ScrollMarkAsRead` setting.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var lastKnownMinY: CGFloat = 0

    private var latestIsRead: Bool {
        feedManager.article(byID: article.id)?.isRead ?? article.isRead
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { newValue in
                lastKnownMinY = newValue
            }
            .onAppear {
                hasBeenVisible = true
                if article.isRead != latestIsRead {
                    #if DEBUG
                    debugPrint("[ScrollMarkAsRead] Stale read state on appear for \(article.id), reloading")
                    #endif
                    feedManager.loadFromDatabase()
                }
            }
            .onDisappear {
                guard scrollMarkAsRead, hasBeenVisible, !latestIsRead else { return }
                // Only mark as read when the row scrolled off the TOP of the
                // viewport (user scrolled down past it). A negative minY means
                // the row's top edge is above the screen's origin.
                guard lastKnownMinY < 0 else { return }
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
}

extension View {
    func markReadOnScroll(article: Article) -> some View {
        modifier(MarkReadOnScrollModifier(article: article))
    }
}
