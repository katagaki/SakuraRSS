import SwiftUI
import Hanami

/// Installs the shared detail presenter and its sheet. Applied once per
/// Bookmarks surface, above the rows that request it from their menus.
struct BookmarkDetailSheetModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager

    @State private var presenter = BookmarkDetailPresenter()

    func body(content: Content) -> some View {
        content
            .environment(presenter)
            .sheet(item: Binding(
                get: { presenter.article },
                set: { presenter.article = $0 }
            )) { article in
                BookmarkDetailSheet(article: article)
                    .environment(feedManager)
                    .presentationDetents([.large])
            }
    }
}

extension View {
    func bookmarkDetailSheet() -> some View {
        modifier(BookmarkDetailSheetModifier())
    }
}
