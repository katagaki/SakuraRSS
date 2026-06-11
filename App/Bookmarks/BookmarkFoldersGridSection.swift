import SwiftUI
import Hanami

struct BookmarkFoldersGridSection: View {

    @Environment(FeedManager.self) var feedManager
    let onFolderSelected: (BookmarkFolder) -> Void

    private let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Folders.Header", table: "Articles"))
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                ForEach(feedManager.bookmarkFolders) { folder in
                    // Buttons with .borderless keep taps isolated inside a
                    // List row; NavigationLinks here would all fire at once.
                    Button {
                        onFolderSelected(folder)
                    } label: {
                        BookmarkFolderGridCell(folder: folder)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
