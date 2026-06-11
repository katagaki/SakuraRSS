import SwiftUI
import Hanami

struct BookmarkFoldersGridSection: View {

    @Environment(FeedManager.self) var feedManager
    let onFolderSelected: (BookmarkFolder) -> Void

    @State private var folderBeingEdited: BookmarkFolder?
    @State private var folderPendingDeletion: BookmarkFolder?
    @State private var isShowingDeleteDialog = false

    private let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Folders.Header", table: "Articles"))
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                ForEach(feedManager.bookmarkFolders) { folder in
                    folderCell(for: folder)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .sheet(item: $folderBeingEdited) { folder in
            BookmarkFolderEditSheet(folder: folder)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        .confirmationDialog(
            String(localized: "FolderMenu.Delete.Title", table: "Articles"),
            isPresented: $isShowingDeleteDialog,
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { folder in
            Button(String(localized: "FolderMenu.Delete.DeleteBookmarks", table: "Articles"),
                   role: .destructive) {
                feedManager.deleteBookmarkFolder(folder, removeBookmarks: true)
            }
            Button(String(localized: "FolderMenu.Delete.KeepBookmarks", table: "Articles")) {
                feedManager.deleteBookmarkFolder(folder, removeBookmarks: false)
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: { folder in
            Text(String(localized: "FolderMenu.Delete.Message.\(folder.name)", table: "Articles"))
        }
    }

    @ViewBuilder
    private func folderCell(for folder: BookmarkFolder) -> some View {
        // Buttons with .borderless keep taps isolated inside a
        // List row; NavigationLinks here would all fire at once.
        Button {
            onFolderSelected(folder)
        } label: {
            BookmarkFolderGridCell(folder: folder)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .contextMenu {
            Button {
                folderBeingEdited = folder
            } label: {
                Label(String(localized: "FolderHeader.Edit", table: "Articles"),
                      systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                folderPendingDeletion = folder
                isShowingDeleteDialog = true
            } label: {
                Label(String(localized: "FolderMenu.Delete", table: "Articles"),
                      systemImage: "trash")
            }
        }
        // Lazy containers reuse the context menu interaction, which can
        // present the previously long-pressed item's menu without an
        // explicit identity.
        .id(folder.id)
        .dropDestination(for: String.self) { payloads, _ in
            moveDroppedBookmarks(payloads, to: folder)
        }
    }

    private func moveDroppedBookmarks(_ payloads: [String], to folder: BookmarkFolder) -> Bool {
        let articleIDs = payloads.compactMap(BookmarkDragPayload.decode)
        guard !articleIDs.isEmpty else { return false }
        withAnimation(.smooth.speed(2.0)) {
            for articleID in articleIDs {
                feedManager.moveBookmark(articleID: articleID, to: folder)
            }
        }
        return true
    }
}
