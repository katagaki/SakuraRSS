import SwiftUI

struct ImageBlockView: View {

    let url: URL
    var link: URL?
    let namespace: Namespace.ID
    var onTap: (() -> Void)?
    @State private var aspectRatio: CGFloat?
    @State private var imageSize: CGSize?
    @State private var loadedImage: UIImage?
    @Environment(\.openURL) private var openURL

    var body: some View {
        imageView
            .matchedTransitionSource(id: url, in: namespace)
            .onTapGesture { onTap?() }
            .contextMenu { contextMenuContent }
    }

    private var effectiveAspectRatio: CGFloat {
        aspectRatio ?? (16.0 / 9.0)
    }

    @ViewBuilder
    private var imageView: some View {
        CachedAsyncImage(url: url, onImageLoaded: { image in
            aspectRatio = image.size.width / image.size.height
            imageSize = image.size
            loadedImage = image
        }, placeholder: {
            Rectangle()
                .fill(.secondary.opacity(0.1))
        })
        .aspectRatio(effectiveAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
        }
        .overlay(alignment: .bottomTrailing) {
            linkBadge
        }
    }

    @ViewBuilder
    private var linkBadge: some View {
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

    @ViewBuilder
    private var contextMenuContent: some View {
        if let loadedImage {
            Button {
                UIPasteboard.general.image = loadedImage
                Haptics.notify(.success)
            } label: {
                Label(
                    String(localized: "ContentBlock.Image.Copy", table: "Articles"),
                    systemImage: "square.on.square"
                )
            }
            ShareLink(
                item: Image(uiImage: loadedImage),
                preview: SharePreview(
                    String(localized: "ContentBlock.Image.SharePreview", table: "Articles"),
                    image: Image(uiImage: loadedImage)
                )
            ) {
                Label(
                    String(localized: "ContentBlock.Image.Share", table: "Articles"),
                    systemImage: "square.and.arrow.up"
                )
            }
        }
    }
}
