import SwiftUI

struct ImageBlockView: View {

    let url: URL
    var link: URL?
    let namespace: Namespace.ID
    var onTap: (() -> Void)?
    @State private var aspectRatio: CGFloat?
    @State private var imageSize: CGSize?
    @Environment(\.openURL) private var openURL

    var body: some View {
        CachedAsyncImage(url: url, onImageLoaded: { image in
            aspectRatio = image.size.width / image.size.height
            imageSize = image.size
        }, placeholder: {
            Rectangle()
                .fill(.secondary.opacity(0.1))
        })
        .aspectRatio(max(aspectRatio ?? (16.0 / 9.0), 16.0 / 9.0), contentMode: .fill)
        .frame(maxWidth: imageSize?.width)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            if let link, (imageSize?.width ?? 120) >= 120 {
                Button {
                    openURL(link)
                } label: {
                    Label("Shared.Link", systemImage: "link")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .matchedTransitionSource(id: url, in: namespace)
        .onTapGesture { onTap?() }
    }
}
