import SwiftUI

struct RemoteImage: View {

    let url: URL

    var body: some View {
        CachedImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
            case .failure:
                EmptyView()
            default:
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quinary)
                    .frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
