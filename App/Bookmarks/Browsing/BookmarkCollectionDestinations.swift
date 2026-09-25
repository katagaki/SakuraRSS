import SwiftUI
import Hanami

struct BookmarkCollectionDestinations: ViewModifier {

    @Environment(BrowserTabStore.self) private var browserStore: BrowserTabStore?
    @Environment(\.browserTabID) private var browserTabID
    @Namespace private var fallbackNamespace
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: BookmarkTag.self) { tag in
                tagDestination(tag)
                    .browserPage(title: tag.name, symbolName: "tag")
                    .environment(\.browserPathToken, .bookmarkTag(tag.id))
            }
            .navigationDestination(for: BookmarkFolder.self) { folder in
                folderDestination(folder)
                    .browserPage(title: folder.name, symbolName: folder.icon)
                    .environment(\.browserPathToken, .bookmarkFolder(folder.id))
            }
    }

    @ViewBuilder
    private func tagDestination(_ tag: BookmarkTag) -> some View {
        if let browserStore, let browserTabID {
            BookmarkTagArticlesView(tag: tag)
                .browserNavigationEnvironment(
                    path: browserStore.pathBinding(for: browserTabID),
                    namespace: namespace ?? fallbackNamespace
                )
        } else {
            BookmarkTagArticlesView(tag: tag)
                .environment(\.zoomNamespace, namespace)
        }
    }

    @ViewBuilder
    private func folderDestination(_ folder: BookmarkFolder) -> some View {
        if let browserStore, let browserTabID {
            BookmarkFolderArticlesView(folder: folder)
                .browserNavigationEnvironment(
                    path: browserStore.pathBinding(for: browserTabID),
                    namespace: namespace ?? fallbackNamespace
                )
        } else {
            BookmarkFolderArticlesView(folder: folder)
                .environment(\.zoomNamespace, namespace)
        }
    }
}

extension View {
    func bookmarkCollectionDestinations(namespace: Namespace.ID?) -> some View {
        modifier(BookmarkCollectionDestinations(namespace: namespace))
    }
}
