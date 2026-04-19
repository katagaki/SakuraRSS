import SwiftUI

/// Marks an article as read once it has been visible and then scrolled out of
/// view. Enabled only when the user has opted in via the
/// `Display.ScrollMarkAsRead` setting.
struct MarkReadOnScrollModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    let article: Article

    @State private var hasBeenVisible = false
    @State private var hasScrolledPastTop = false
    @State private var hasQueued = false

    func body(content: Content) -> some View {
        content
            // Track only the boolean transition of crossing the viewport's top
            // edge. `onGeometryChange` diffs the observed value, so `action`
            // fires only when the boolean flips (instead of on every scroll
            // frame when we were observing `minY` directly).
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .global).minY < 0
            } action: { newValue in
                hasScrolledPastTop = newValue
            }
            .onAppear {
                hasBeenVisible = true
            }
            .onDisappear {
                guard scrollMarkAsRead, hasBeenVisible, hasScrolledPastTop,
                      !hasQueued, !article.isRead else { return }
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
