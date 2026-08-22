import SwiftUI
import Hanami

struct PhotosArticleCardMedia: View {

    let article: Article
    let maxPixelSize: CGFloat
    @Binding var photoImage: UIImage?
    @Binding var imageAspectRatio: CGFloat?
    @State private var currentPage: Int = 0

    private static let minimumAspectRatio: CGFloat = 4.0 / 5.0

    private var effectiveAspectRatio: CGFloat {
        max(imageAspectRatio ?? Self.minimumAspectRatio, Self.minimumAspectRatio)
    }

    var body: some View {
        if article.carouselImageURLs.count > 1 {
            carouselView
        } else if let photoImage, article.imageURL != nil {
            singleImageView(photoImage)
        }
    }

    @ViewBuilder
    private var carouselView: some View {
        let urls = article.carouselImageURLs.compactMap { URL(string: $0) }
        if !urls.isEmpty {
            TabView(selection: $currentPage) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    CachedAsyncImage(url: url, maxPixelSize: maxPixelSize) {
                        Rectangle()
                            .fill(.secondary.opacity(0.1))
                    }
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(effectiveAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottom) {
                PageDotsView(count: urls.count, current: currentPage)
                    .padding(.bottom, 8)
            }
            .task {
                let loaded = await CachedAsyncImage<EmptyView>.loadImage(
                    from: urls[0], maxPixelSize: maxPixelSize
                )
                if photoImage !== loaded {
                    photoImage = loaded
                }
                if let loaded, loaded.size.height > 0 {
                    let ratio = loaded.size.width / loaded.size.height
                    if imageAspectRatio != ratio {
                        imageAspectRatio = ratio
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func singleImageView(_ image: UIImage) -> some View {
        Color.clear
            .aspectRatio(effectiveAspectRatio, contentMode: .fit)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .debugLayout()
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .allowsHitTesting(false)
            .overlay {
                if article.url.contains("/reel/") {
                    ArticleLink(article: article, label: {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(.primary)
                            .padding(16)
                            .background(.ultraThinMaterial, in: .circle)
                            .compatibleGlassEffect(in: .circle, interactive: true)
                    })
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)
            .transition(.opacity)
    }
}
