import SwiftUI
import Hanami

/// Last step of the bookmark preview chain: the site's own icon, for saved
/// pages that have no preview image and no feed to borrow artwork from.
struct BookmarkSiteIcon: View {

    let article: Article
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    @State private var icon: PlatformImage?

    var body: some View {
        Group {
            if let icon {
                Image(platformImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
            } else {
                InitialsAvatarView(BookmarkSite.name(of: article) ?? article.displayTitle,
                                   size: size, cornerRadius: cornerRadius)
            }
        }
        .frame(width: size, height: size)
        .background(.quinary)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .task(id: article.url) {
            icon = await BookmarkSite.icon(for: article)
        }
    }
}
