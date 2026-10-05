import SwiftUI
import Hanami

/// Last step of the bookmark preview chain: the site's own icon, for saved
/// pages that have no preview image and no feed to borrow artwork from.
struct BookmarkSiteIcon: View {

    let article: Article
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    @State private var icon: PlatformImage?

    private var host: String? {
        URL(string: article.url)?.host()
    }

    var body: some View {
        Group {
            if let icon {
                Image(platformImage: icon)
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
            let siteURL = AppStoreFeedIcons.appID(for: host) == nil ? article.url : nil
            icon = await Iconography.shared.icon(for: host, siteURL: siteURL)
        }
    }
}
