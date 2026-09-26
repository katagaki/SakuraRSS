import SwiftUI
import Hanami

struct BookmarkFolderReadingSection: View {

    @Binding var openMode: FeedOpenMode?
    @Binding var marksReadOnOpen: Bool?

    var body: some View {
        Section {
            Picker(String(localized: "FolderEdit.OpenIn", table: "Articles"), selection: $openMode) {
                Text(String(localized: "FolderEdit.OpenIn.Inherit", table: "Articles"))
                    .tag(FeedOpenMode?.none)
                Divider()
                Text(String(localized: "FeedEdit.OpenIn.InAppViewer", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.inAppViewer))
                Divider()
                Text(String(localized: "FeedEdit.OpenIn.Browser", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.browser))
                Text(String(localized: "FeedEdit.OpenIn.InAppBrowser", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.inAppBrowser))
                Text(String(localized: "FeedEdit.OpenIn.InAppBrowserReader", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.inAppBrowserReader))
                Divider()
                Text(String(localized: "FeedEdit.OpenIn.ClearThisPage", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.clearThisPage))
                Text(String(localized: "FeedEdit.OpenIn.Readability", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.readability))
                Text(String(localized: "FeedEdit.OpenIn.ArchivePh", table: "Feeds"))
                    .tag(FeedOpenMode?.some(.archivePh))
            }

            Picker(String(localized: "FolderEdit.MarkRead", table: "Articles"), selection: $marksReadOnOpen) {
                Text(String(localized: "FolderEdit.MarkRead.Inherit", table: "Articles"))
                    .tag(Bool?.none)
                Text(String(localized: "FolderEdit.MarkRead.Always", table: "Articles"))
                    .tag(Bool?.some(true))
                Text(String(localized: "FolderEdit.MarkRead.Never", table: "Articles"))
                    .tag(Bool?.some(false))
            }
        } header: {
            Text(String(localized: "FolderEdit.Reading", table: "Articles"))
        } footer: {
            Text(String(localized: "FolderEdit.Reading.Footer", table: "Articles"))
        }
    }
}
