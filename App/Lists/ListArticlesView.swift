import SwiftUI
import Hanami

struct ListArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss
    let list: FeedList

    @State private var effectiveDisplayStyle: FeedDisplayStyle?

    private var currentList: FeedList {
        feedManager.lists.first(where: { $0.id == list.id }) ?? list
    }

    private var listExists: Bool {
        feedManager.lists.contains(where: { $0.id == list.id })
    }

    private var styleSupportsRichHeader: Bool {
        effectiveDisplayStyle?.supportsRichHeader ?? true
    }

    var body: some View {
        HomeSectionView(
            list: currentList,
            showsListHeader: true,
            showsLastUpdated: false,
            effectiveStyleBinding: $effectiveDisplayStyle
        )
        .onChange(of: listExists) { _, exists in
            if !exists { dismiss() }
        }
        .animation(.smooth.speed(2.0), value: styleSupportsRichHeader)
    }
}
