import SwiftUI

/// The Mac's stand-in for iOS's `CachedAsyncImage`, which decodes through
/// UIKit; shared views that show remote thumbnails build here too.
struct CachedAsyncImage<Placeholder: View>: View {

    let url: URL?
    let maxPixelSize: CGFloat
    let placeholder: () -> Placeholder

    init(url: URL?, maxPixelSize: CGFloat = 400, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder
    }

    var body: some View {
        CachedImage(url: url) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
    }
}
