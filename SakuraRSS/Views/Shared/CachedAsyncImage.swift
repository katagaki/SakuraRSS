import SwiftUI

// MARK: - In-Memory Image Cache

/// Shared memory cache for decoded UIImages.
nonisolated final class ImageMemoryCache: @unchecked Sendable {

    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 150 * 1024 * 1024 // 150 MB
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let cost = Int(width * height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

private enum CachedAsyncImageConfig {
    nonisolated static let maxDisplayPixelSize: CGFloat = 2000
}

struct CachedAsyncImage<Placeholder: View>: View {

    let url: URL?
    let alignment: Alignment
    let onImageLoaded: ((UIImage) -> Void)?
    let placeholder: () -> Placeholder
    @State private var image: UIImage?
    @State private var isLoading: Bool
    @State private var reportedCachedHit = false

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
        let initial: UIImage? = {
            guard let url, !url.absoluteString.hasPrefix("data:") else { return nil }
            return ImageMemoryCache.shared.image(forKey: url.absoluteString)
        }()
        _image = State(initialValue: initial)
        _isLoading = State(initialValue: initial == nil)
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
            } else {
                placeholder()
            }
        }
        .task(id: url, priority: .utility) {
            guard let url else {
                isLoading = false
                return
            }
            if let image {
                if !reportedCachedHit {
                    reportedCachedHit = true
                    onImageLoaded?(image)
                }
                isLoading = false
                return
            }
            let loadedImage = await Self.loadImage(from: url)
            if Task.isCancelled { return }
            image = loadedImage
            if let loadedImage {
                onImageLoaded?(loadedImage)
            }
            isLoading = false
        }
    }

    /// Largest dimension ever displayed; originals are downsampled to this size.
    nonisolated static var maxDisplayPixelSize: CGFloat {
        CachedAsyncImageConfig.maxDisplayPixelSize
    }

    nonisolated static func loadImage(from url: URL) async -> UIImage? {
        let urlString = url.absoluteString

        if urlString.hasPrefix("data:") {
            return nil
        }

        let memoryCache = ImageMemoryCache.shared
        if let cached = memoryCache.image(forKey: urlString) {
            return cached
        }

        let database = DatabaseManager.shared

        if let cachedData = try? database.cachedImageData(for: urlString),
           let cachedImage = ImageDownsampler.downsample(
               cachedData, maxPixelSize: maxDisplayPixelSize
           ) ?? UIImage(data: cachedData) {
            memoryCache.setImage(cachedImage, forKey: urlString)
            #if DEBUG
            debugPrint("[Image] Cache hit for \(urlString) (\(cachedData.count) bytes)")
            #endif
            return cachedImage
        }

        #if DEBUG
        debugPrint("[Image] Cache miss, downloading \(urlString)")
        #endif

        do {
            let (data, response) = try await URLSession.shared.data(for: .sakuraImage(url: url))
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            #if DEBUG
            debugPrint("[Image] Downloaded \(urlString): \(data.count) bytes, HTTP \(statusCode ?? 0)")
            #endif
            let downsampled = ImageDownsampler.downsample(
                data, maxPixelSize: maxDisplayPixelSize
            ) ?? UIImage(data: data)
            guard let downsampled else {
                #if DEBUG
                debugPrint("[Image] Failed to decode image data from \(urlString) (\(data.count) bytes)")
                #endif
                return nil
            }
            if memoryCache.image(forKey: urlString) == nil {
                try? database.cacheImageData(data, for: urlString)
            }
            memoryCache.setImage(downsampled, forKey: urlString)
            return downsampled
        } catch {
            #if DEBUG
            debugPrint("[Image] Download failed for \(urlString): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
