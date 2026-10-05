import Hanami
import SwiftUI

/// `AsyncImage`, loading through `CachedImageData` so cached images show without a fetch.
/// `content` has to draw something in every phase: a task on an empty view never starts.
struct CachedImage<Content: View>: View {

    let url: URL?
    let maxPixelSize: CGFloat
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase

    init(
        url: URL?,
        maxPixelSize: CGFloat = ImageDownsampler.cacheMaxPixelSize,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
        _phase = State(initialValue: Self.cachedPhase(url: url, maxPixelSize: maxPixelSize))
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                // Lazy containers reuse this view's state for other URLs.
                phase = Self.cachedPhase(url: url, maxPixelSize: maxPixelSize)
                guard let url, phase.image == nil else { return }
                guard let image = await CachedImageData.image(url, maxPixelSize: maxPixelSize) else {
                    if !Task.isCancelled {
                        phase = .failure(URLError(.cannotDecodeContentData))
                    }
                    return
                }
                phase = .success(Image(nsImage: image))
            }
    }

    private static func cachedPhase(url: URL?, maxPixelSize: CGFloat) -> AsyncImagePhase {
        guard let url, let image = CachedImageData.cachedImage(url, maxPixelSize: maxPixelSize) else {
            return .empty
        }
        return .success(Image(nsImage: image))
    }
}
