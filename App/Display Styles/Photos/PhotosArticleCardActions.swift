import SwiftUI
import Hanami

struct PhotosArticleCardActions: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article
    let photoImage: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            Button {
                log("PhotosCard", "Copy tapped for article \(article.id), photoImage=\(photoImage != nil)")
                Haptics.impact(.light)
                if let photoImage {
                    UIPasteboard.general.image = photoImage
                }
            } label: {
                Label(String(localized: "Article.CopyPhoto", table: "Articles"),
                      systemImage: "square.on.square")
            }

            ShareLink(item: URL(string: article.url) ?? URL(string: "https://")!) {
                Label(String(localized: "Article.Share", table: "Articles"),
                      systemImage: "square.and.arrow.up")
            }
            .padding(.bottom, 1)
            .disabled(URL(string: article.url) == nil)

            Spacer()

            let isBookmarked = feedManager.isBookmarked(article)
            Button {
                log("PhotosCard", "Bookmark tapped for article \(article.id)")
                Haptics.impact(.light)
                feedManager.toggleBookmark(article)
            } label: {
                Label(
                    isBookmarked
                        ? String(localized: "Article.RemoveBookmark", table: "Articles")
                        : String(localized: "Article.Bookmark", table: "Articles"),
                    systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                )
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
