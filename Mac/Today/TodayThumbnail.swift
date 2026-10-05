import SwiftUI

struct TodayThumbnail: View {

    let urlString: String?

    var body: some View {
        Rectangle()
            .fill(.quinary)
            .overlay {
                if let urlString, let url = URL(string: urlString) {
                    CachedImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                } else {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
    }
}
