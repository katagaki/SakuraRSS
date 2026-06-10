import SwiftUI
import Hanami

struct ImageBlockView: View {

    let url: URL
    var link: URL?
    let namespace: Namespace.ID
    var onTap: (() -> Void)?
    @State private var aspectRatio: CGFloat?
    @State private var imageSize: CGSize?
    @State private var loadedImage: UIImage?
    @Environment(\.openURL) private var openURL

    init(url: URL, link: URL? = nil, namespace: Namespace.ID, onTap: (() -> Void)? = nil) {
        self.url = url
        self.link = link
        self.namespace = namespace
        self.onTap = onTap
        if let ratio = ImageAspectRatioCache.shared.aspectRatio(for: url.absoluteString) {
            _aspectRatio = State(initialValue: ratio)
        }
    }

    var body: some View {
        imageView
            .matchedTransitionSource(id: url, in: namespace)
            .onTapGesture { onTap?() }
            .contextMenu { contextMenuContent }
    }

    private var effectiveAspectRatio: CGFloat {
        aspectRatio ?? (16 / 9)
    }

    @ViewBuilder
    private var imageView: some View {
        CachedAsyncImage(url: url, onImageLoaded: { image in
            let ratio = image.size.width / image.size.height
            if aspectRatio != ratio {
                aspectRatio = ratio
            }
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
