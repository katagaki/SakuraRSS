import SwiftUI

/// Image fitted to a fixed height; width follows the natural aspect ratio.
struct CarouselImageView: View {

    let url: URL
    let height: CGFloat
    @State private var image: UIImage?

    init(url: URL, height: CGFloat) {
        self.url = url
        self.height = height
        // Paint memory-cache hits on first render to avoid placeholder flash during scroll.
        _image = State(initialValue: ImageMemoryCache.shared.image(forKey: url.absoluteString))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
                    .debugLayout()
            } else {
                Color.secondary.opacity(0.1)
                    .frame(width: 200, height: height)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary, lineWidth: 0.5)
        }
        .task(priority: .utility) {
            if image != nil { return }
            let loaded = await CachedAsyncImage<EmptyView>.loadImage(from: url)
            if Task.isCancelled { return }
            image = loaded
        }
    }
}
