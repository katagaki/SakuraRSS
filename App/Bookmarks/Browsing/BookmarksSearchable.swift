import SwiftUI

/// `.searchable` needs a navigation bar, which the browser hides, so it is
/// applied only where there is one to hold it.
struct BookmarksSearchable: ViewModifier {

    @Binding var text: String
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(
                text: $text,
                prompt: String(localized: "Bookmarks.Search.Prompt", table: "Articles")
            )
        } else {
            content
        }
    }
}

extension View {
    func bookmarksSearchable(text: Binding<String>, isEnabled: Bool) -> some View {
        modifier(BookmarksSearchable(text: text, isEnabled: isEnabled))
    }
}
