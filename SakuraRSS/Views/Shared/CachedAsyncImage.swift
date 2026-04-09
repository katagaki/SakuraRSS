import SwiftUI

// MARK: - In-Memory Image Cache

/// Shared memory cache for decoded UIImages, avoiding repeated SQLite
/// lookups and Data → UIImage decoding during scroll recycling.
/// NSCache automatically evicts entries under memory pressure.
private final class ImageMemoryCache: @unchecked Sendable {

    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 150 * 1024 * 1024 // 150 MB
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let cost = Int(w * h * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

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
                Color.clear
                    .overlay(alignment: alignment) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
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

        // 1. In-memory cache (instant, no decoding)
        let memoryCache = ImageMemoryCache.shared
        if let cached = memoryCache.image(forKey: urlString) {
            return cached
        }

        let database = DatabaseManager.shared

        // 2. Database cache (requires Data → UIImage decode)
        if let cachedData = try? database.cachedImageData(for: urlString),
           let cachedImage = UIImage(data: cachedData) {
            memoryCache.setImage(cachedImage, forKey: urlString)
            #if DEBUG
            debugPrint("[Image] Cache hit for \(urlString) (\(cachedData.count) bytes)")
            #endif
            return cachedImage
        }

        #if DEBUG
        debugPrint("[Image] Cache miss, downloading \(urlString)")
        #endif

        // 3. Network download
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
            memoryCache.setImage(downloadedImage, forKey: urlString)
            return downloadedImage
        } catch {
            #if DEBUG
            debugPrint("[Image] Download failed for \(urlString): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
