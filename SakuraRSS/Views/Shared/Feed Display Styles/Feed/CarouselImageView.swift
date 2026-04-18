import SwiftUI

/// Loads and displays an image fitted to a fixed height, letting
/// its natural aspect ratio determine the width.
struct CarouselImageView: View {

    let url: URL
    let height: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
            } else {
                Color.secondary.opacity(0.1)
                    .frame(width: 200, height: height)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        }
        .task {
            image = await CachedAsyncImage<EmptyView>.loadImage(from: url)
        }
    }
}
