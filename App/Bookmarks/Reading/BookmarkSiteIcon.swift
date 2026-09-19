import SwiftUI
import Hanami

/// Last step of the bookmark preview chain: the site's own icon, for saved
/// pages that have no preview image and no feed to borrow artwork from.
struct BookmarkSiteIcon: View {

    let article: Article
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    @State private var icon: UIImage?

    private var host: String? {
        URL(string: article.url)?.host()
    }

    var body: some View {
        Group {
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
            } else {
                InitialsAvatarView(host ?? article.displayTitle, size: size, cornerRadius: cornerRadius)
            }
        }
        .frame(width: size, height: size)
        .background(.quinary)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .task(id: article.url) {
            guard let host else { return }
            icon = await Iconography.shared.icon(for: host, siteURL: article.url)
        }
    }
}
