import SwiftUI

struct CachedAsyncImage<Placeholder: View>: View {

    let url: URL?
    let alignment: Alignment
    let onImageLoaded: ((UIImage) -> Void)?
    let placeholder: () -> Placeholder
    @State private var image: UIImage?
    @State private var isLoading = true

    init(
        url: URL?,
        alignment: Alignment = .center,
        onImageLoaded: ((UIImage) -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.alignment = alignment
        self.onImageLoaded = onImageLoaded
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                }
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                isLoading = false
                return
            }
            let loadedImage = await Self.loadImage(from: url)
            image = loadedImage
            if let loadedImage {
                onImageLoaded?(loadedImage)
            }
            isLoading = false
        }
    }

    nonisolated static func loadImage(from url: URL) async -> UIImage? {
        let urlString = url.absoluteString
        let database = DatabaseManager.shared

        if let cachedData = try? database.cachedImageData(for: urlString),
           let cachedImage = UIImage(data: cachedData) {
            return cachedImage
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downloadedImage = UIImage(data: data) else { return nil }
            try? database.cacheImageData(data, for: urlString)
            return downloadedImage
        } catch {
            return nil
        }
    }
}
