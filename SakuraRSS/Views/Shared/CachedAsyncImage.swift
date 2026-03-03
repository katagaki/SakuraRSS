import SwiftUI

struct CachedAsyncImage<Placeholder: View>: View {

    let url: URL?
    let placeholder: () -> Placeholder
    @State private var image: UIImage?
    @State private var isLoading = true

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                isLoading = false
                return
            }
            image = await Self.loadImage(from: url)
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
