import SwiftUI
import Hanami

struct FeedImageCarouselView: View {

    let urls: [URL]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                    CarouselImageView(url: url, height: 300)
                }
            }
        }
        .scrollClipDisabled()
        .contentMargins(.horizontal, 0)
    }
}
