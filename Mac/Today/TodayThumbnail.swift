import SwiftUI

struct TodayThumbnail: View {

    let urlString: String?

    var body: some View {
        Rectangle()
            .fill(.quinary)
            .overlay {
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                } else {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
    }
}
