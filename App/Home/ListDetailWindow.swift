#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct ListDetailWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let listID: Int64

    private var list: FeedList? {
        feedManager.lists.first { $0.id == listID }
    }

    var body: some View {
        if let list {
            DetachedFeedNavigationStack {
                ListArticlesView(list: list)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
