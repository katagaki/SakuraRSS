import SwiftUI

/// An image at its own proportions, for the masonry style's staggered columns.
struct ContentNaturalImage: View {

    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Rectangle()
                    .fill(.quinary)
                    .frame(height: 160)
            }
            .clipShape(.rect(cornerRadius: 10))
        }
    }
}
