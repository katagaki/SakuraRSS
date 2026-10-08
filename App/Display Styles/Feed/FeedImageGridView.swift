import SwiftUI
import Hanami

/// Lays out up to four images in one rounded frame, the way social apps tile
/// multi-image posts.
struct FeedImageGridView: View {

    static let maximumImageCount = 4

    let urls: [URL]
    var height: CGFloat = 240

    private let spacing: CGFloat = 2
    private let cornerRadius: CGFloat = 12

    private var visibleURLs: [URL] {
        Array(urls.prefix(Self.maximumImageCount))
    }

    var body: some View {
        tiles
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    @ViewBuilder
    private var tiles: some View {
        let urls = visibleURLs
        switch urls.count {
        case 0:
            EmptyView()
        case 1:
            tile(urls[0], corners: [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing])
        case 2:
            HStack(spacing: spacing) {
                tile(urls[0], corners: [.topLeading, .bottomLeading])
                tile(urls[1], corners: [.topTrailing, .bottomTrailing])
            }
        case 3:
            HStack(spacing: spacing) {
                tile(urls[0], corners: [.topLeading, .bottomLeading])
                VStack(spacing: spacing) {
                    tile(urls[1], corners: [.topTrailing])
                    tile(urls[2], corners: [.bottomTrailing])
                }
            }
        default:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    tile(urls[0], corners: [.topLeading])
                    tile(urls[1], corners: [.topTrailing])
                }
                HStack(spacing: spacing) {
                    tile(urls[2], corners: [.bottomLeading])
                    tile(urls[3], corners: [.bottomTrailing])
                }
            }
        }
    }

    private func tile(_ url: URL, corners: Set<RoundedCorner>) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: corners.contains(.topLeading) ? cornerRadius : 0,
            bottomLeadingRadius: corners.contains(.bottomLeading) ? cornerRadius : 0,
            bottomTrailingRadius: corners.contains(.bottomTrailing) ? cornerRadius : 0,
            topTrailingRadius: corners.contains(.topTrailing) ? cornerRadius : 0
        )
        return CachedAsyncImage(url: url, maxPixelSize: CarouselImageView.maxPixelSize) {
            Color.secondary.opacity(0.1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
        }
    }

    private enum RoundedCorner {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }
}
