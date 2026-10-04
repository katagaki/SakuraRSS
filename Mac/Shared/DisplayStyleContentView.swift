import Hanami
import SwiftUI

/// The Mac's stand-in for iOS's `DisplayStyleContentView`, used by the shared
/// edit feed sheet's style preview.
struct DisplayStyleContentView: View {

    let style: FeedDisplayStyle
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var onRefresh: (() async -> Void)?

    var body: some View {
        ScrollView {
            if style.isListStyle {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(articles) { article in
                        ContentGridCaption(article: article, feedTitle: nil, isRead: false, titleLines: 2)
                        Divider()
                    }
                }
                .padding()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(articles) { article in
                        ContentGridItem(article: article, feedTitle: nil, isRead: false, style: style)
                    }
                }
                .padding()
            }
        }
    }
}
