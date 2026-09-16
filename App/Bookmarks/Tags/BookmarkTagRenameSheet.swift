import SwiftUI
import Hanami

struct BookmarkTagRenameSheet: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.dismiss) private var dismiss

    let tag: BookmarkTag

    @State private var name = ""
    @FocusState private var isNameFieldFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "TagRename.Placeholder", table: "Articles"), text: $name)
                    .focused($isNameFieldFocused)
            }
            .navigationTitle(String(localized: "TagMenu.Rename", table: "Articles"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        feedManager.renameBookmarkTag(tag, to: trimmedName)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                name = tag.name
                isNameFieldFocused = true
            }
        }
    }
}
