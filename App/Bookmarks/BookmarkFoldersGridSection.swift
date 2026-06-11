import SwiftUI
import Hanami

struct BookmarkFoldersGridSection: View {

    @Environment(FeedManager.self) var feedManager

    private let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Folders.Header", table: "Articles"))
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                ForEach(feedManager.bookmarkFolders) { folder in
                    NavigationLink(value: folder) {
                        BookmarkFolderGridCell(folder: folder)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
