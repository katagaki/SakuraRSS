import SwiftUI
import Hanami

/// Lays out up to four images in one rounded frame, the way social apps tile
/// multi-image posts.
struct FeedImageGridView: View {

    static let maximumImageCount = 4

    let urls: [URL]
    var height: CGFloat = 240

    private let spacing: CGFloat = 2

    private var visibleURLs: [URL] {
        Array(urls.prefix(Self.maximumImageCount))
    }

    var body: some View {
        tiles
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    private var tiles: some View {
        let urls = visibleURLs
        switch urls.count {
        case 0:
            EmptyView()
        case 1:
            tile(urls[0])
        case 2:
            HStack(spacing: spacing) {
                tile(urls[0])
                tile(urls[1])
            }
        case 3:
            HStack(spacing: spacing) {
                tile(urls[0])
                VStack(spacing: spacing) {
                    tile(urls[1])
                    tile(urls[2])
                }
            }
        default:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    tile(urls[0])
                    tile(urls[1])
                }
                HStack(spacing: spacing) {
                    tile(urls[2])
                    tile(urls[3])
                }
            }
        }
    }

    private func tile(_ url: URL) -> some View {
        CachedAsyncImage(url: url, maxPixelSize: CarouselImageView.maxPixelSize) {
            Color.secondary.opacity(0.1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
