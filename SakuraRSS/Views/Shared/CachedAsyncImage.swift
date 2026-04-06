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
                        .clipped()
                }
            } else if isLoading {
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

        // Skip data: URIs — they are typically inline SVG placeholders
        // (e.g. Next.js blur-up shims) that contain no useful image content.
        if urlString.hasPrefix("data:") {
            return nil
        }

        let database = DatabaseManager.shared

        if let cachedData = try? database.cachedImageData(for: urlString),
           let cachedImage = UIImage(data: cachedData) {
            #if DEBUG
            debugPrint("[Image] Cache hit for \(urlString) (\(cachedData.count) bytes)")
            #endif
            return cachedImage
        }

        #if DEBUG
        debugPrint("[Image] Cache miss, downloading \(urlString)")
        #endif

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            #if DEBUG
            debugPrint("[Image] Downloaded \(urlString): \(data.count) bytes, HTTP \(statusCode ?? 0)")
            #endif
            guard let downloadedImage = UIImage(data: data) else {
                #if DEBUG
                debugPrint("[Image] Failed to decode image data from \(urlString) (\(data.count) bytes)")
                #endif
                return nil
            }
            try? database.cacheImageData(data, for: urlString)
            return downloadedImage
        } catch {
            #if DEBUG
            debugPrint("[Image] Download failed for \(urlString): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
