import Hanami
import SwiftUI

/// The Scroll style: one phone-shaped page per piece of content, paging
/// vertically through the middle of the window.
struct ContentScrollPager<Page: View>: View {

    let articles: [Article]
    @ViewBuilder let page: (Article) -> Page

    var body: some View {
        GeometryReader { geometry in
            let pageHeight = max(geometry.size.height - 40, 0)
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(articles) { article in
                        page(article)
                            .frame(width: pageHeight * ContentImmersiveTile.pageAspectRatio, height: pageHeight)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.never)
        }
    }
}
