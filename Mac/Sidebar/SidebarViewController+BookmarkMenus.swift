import AppKit
import Hanami

extension SidebarViewController {

    func addBookmarkItems(for location: BrowserLocation, to menu: NSMenu) {
        switch location {
        case .bookmarks:
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem(articlesText("Folders.New"), symbolName: "folder.badge.plus") { [weak self] in
                self?.presentFolderSheet(nil)
            })
        case .bookmarkFolder(let folderID):
            guard let folder = feedManager.bookmarkFolders.first(where: { $0.id == folderID }) else { return }
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem(articlesText("FolderHeader.Edit"), symbolName: "pencil") { [weak self] in
                self?.presentFolderSheet(folder)
            })
            menu.addItem(ActionMenuItem(articlesText("FolderMenu.Delete"), symbolName: "trash") { [weak self] in
                self?.confirmDeleting(folder)
            })
        case .bookmarkTag(let tagID):
            guard let tag = feedManager.allBookmarkTags().first(where: { $0.id == tagID }) else { return }
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem(articlesText("TagMenu.Rename"), symbolName: "pencil") { [weak self] in
                guard let self else { return }
                self.presentSwiftUISheet(BookmarkTagRenameSheet(tag: tag), feedManager: self.feedManager)
            })
            menu.addItem(ActionMenuItem(articlesText("TagMenu.Delete"), symbolName: "trash") { [weak self] in
                self?.feedManager.deleteBookmarkTag(tag)
            })
        default:
            break
        }
    }

    private func presentFolderSheet(_ folder: BookmarkFolder?) {
        presentSwiftUISheet(BookmarkFolderEditSheet(folder: folder), feedManager: feedManager)
    }

    /// iOS's choice: delete the folder alone, or its bookmarks with it.
    private func confirmDeleting(_ folder: BookmarkFolder) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = articlesText("FolderMenu.Delete.Title")
        alert.informativeText = String(localized: "FolderMenu.Delete.Message.\(folder.name)", table: "Articles")
        alert.addButton(withTitle: articlesText("FolderMenu.Delete.KeepBookmarks"))
        alert.addButton(withTitle: articlesText("FolderMenu.Delete.DeleteBookmarks")).hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Shared.Cancel"))
        alert.beginSheetModal(for: window) { [feedManager] response in
            MainActor.assumeIsolated {
                switch response {
                case .alertFirstButtonReturn: feedManager.deleteBookmarkFolder(folder, removeBookmarks: false)
                case .alertSecondButtonReturn: feedManager.deleteBookmarkFolder(folder, removeBookmarks: true)
                default: break
                }
            }
        }
    }

    private func articlesText(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "Articles")
    }
}
