import SwiftUI

/// An image at its own proportions, for the masonry style's staggered columns.
struct ContentNaturalImage: View {

    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            CachedImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle()
                        .fill(.quinary)
                        .frame(height: 160)
                }
            }
            .clipShape(.rect(cornerRadius: 10))
        }
    }
}
