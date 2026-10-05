import SwiftUI
import Hanami

struct BookmarkReadingOptionsModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager

    @State private var optionsByArticleID: [Int64: BookmarkFolderReadingOptions] = [:]

    func body(content: Content) -> some View {
        content
            .environment(\.bookmarkReadingOptions, optionsByArticleID)
            .task(id: feedManager.dataRevision) {
                let loaded = await Task.detached {
                    (try? DatabaseManager.shared.bookmarkFolderReadingOptionsByArticleID()) ?? [:]
                }.value
                if Task.isCancelled { return }
                optionsByArticleID = loaded
            }
    }
}

extension View {
    func bookmarkReadingOptions() -> some View {
        modifier(BookmarkReadingOptionsModifier())
    }
}
