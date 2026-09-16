import SwiftUI

/// The browser hides the navigation bar, and `.searchable` has nowhere to go
/// without one, so Bookmarks carries its own field at the top of the page
/// when it is hosted there.
struct BookmarkInlineSearchField: View {

    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "Bookmarks.Search.Prompt", table: "Articles"),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Shared.Cancel"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quinary, in: .capsule)
        .padding(.horizontal, 16)
    }
}
