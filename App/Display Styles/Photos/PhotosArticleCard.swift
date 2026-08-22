import SwiftUI
import Hanami

struct PhotosArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var icon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipIconInset = false
    @State private var photoImage: UIImage?
    @State private var imageAspectRatio: CGFloat?
    @State private var feed: Feed?

    private static let imageMaxPixelSize: CGFloat = 1600

    init(article: Article) {
        self.article = article
        let aspectSourceURL = article.carouselImageURLs.count > 1
            ? article.carouselImageURLs.first
            : article.imageURL
        if let aspectSourceURL,
           let ratio = ImageAspectRatioCache.shared.aspectRatio(for: aspectSourceURL) {
            _imageAspectRatio = State(initialValue: ratio)
        }
        guard article.carouselImageURLs.count <= 1,
              let imageURL = article.imageURL,
              let url = URL(string: imageURL) else { return }
        let cacheKey = CachedAsyncImage<EmptyView>.cacheKey(url, Self.imageMaxPixelSize)
        if let cachedImage = ImageMemoryCache.shared.image(forKey: cacheKey),
           Self.isDisplayableSize(cachedImage) {
            _photoImage = State(initialValue: cachedImage)
        }
    }

    private static func isDisplayableSize(_ image: UIImage) -> Bool {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        return pixelWidth > 100 || pixelHeight > 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotosArticleCardHeader(
                article: article,
                feed: feed,
                feedName: feedName,
                icon: icon,
                acronymIcon: acronymIcon,
                skipIconInset: skipIconInset
            )

            PhotosArticleCardMedia(
                article: article,
                maxPixelSize: Self.imageMaxPixelSize,
                photoImage: $photoImage,
                imageAspectRatio: $imageAspectRatio
            )

            ArticleLink(article: article, label: {
                let isPhotoFeed = feed?.isInstagramFeed == true || feed?.isPhotoViewDomain == true
                let captionText = isPhotoFeed ? (article.summary ?? article.title) : article.title
                Text(captionText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(isPhotoFeed ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            })
            .buttonStyle(.plain)

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            PhotosArticleCardActions(article: article, photoImage: photoImage)

            Divider()
                .padding(.top, 4)
        }
        .task {
            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                feedName = loadedFeed.title
                acronymIcon = AcronymIconCache.shared.icon(for: loadedFeed)
                skipIconInset = loadedFeed.isVideoFeed || loadedFeed.isXFeed || loadedFeed.isInstagramFeed
                icon = await Iconography.shared.icon(for: loadedFeed)
            }
        }
        .task(id: article.imageURL) {
            guard article.carouselImageURLs.count <= 1,
                  let imageURL = article.imageURL,
                  let url = URL(string: imageURL) else { return }
            let loaded = await CachedAsyncImage<EmptyView>.loadImage(
                from: url, maxPixelSize: Self.imageMaxPixelSize
            )
            guard !Task.isCancelled, let loaded, loaded.size.height > 0,
                  Self.isDisplayableSize(loaded) else { return }
            let aspect = loaded.size.width / loaded.size.height
            if imageAspectRatio != aspect {
                imageAspectRatio = aspect
            }
            if photoImage !== loaded {
                photoImage = loaded
            }
        }
    }
}
