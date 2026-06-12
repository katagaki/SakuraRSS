import SwiftUI
import Hanami

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
    let maxPixelSize: CGFloat
    let alignment: Alignment
    let onImageLoaded: ((UIImage) -> Void)?
    let placeholder: () -> Placeholder
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    @State private var reportedCachedHit = false

    init(
        url: URL?,
        maxPixelSize: CGFloat = CachedAsyncImageConfig.maxDisplayPixelSize,
        alignment: Alignment = .center,
        onImageLoaded: ((UIImage) -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.alignment = alignment
        self.onImageLoaded = onImageLoaded
        self.placeholder = placeholder
        let initial = Self.cachedImage(for: url, maxPixelSize: maxPixelSize)
        _image = State(initialValue: initial)
        _loadedURL = State(initialValue: initial == nil ? nil : url)
    }

    var body: some View {
        ZStack {
            placeholder()
                .opacity(image == nil ? 1 : 0)
            if let image {
                Color.clear
                    .overlay(alignment: alignment) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .debugLayout()
                    }
                    .clipped()
            }
        }
        .background {
            image?.averageColor ?? Color(uiColor: .systemBackground)
        }
        .contentShape(.rect)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .task(id: url, priority: .utility) {
            // State persists across url changes when the view's identity is
            // reused (e.g. lazy containers), so drop the previous url's image.
            if loadedURL != url {
                image = Self.cachedImage(for: url, maxPixelSize: maxPixelSize)
                loadedURL = image == nil ? nil : url
                reportedCachedHit = false
            }
            guard let url else { return }
            if let image {
                if !reportedCachedHit {
                    reportedCachedHit = true
                    onImageLoaded?(image)
                }
                return
            }
            let loadedImage = await Self.loadImage(from: url, maxPixelSize: maxPixelSize)
            if Task.isCancelled { return }
            if let loadedImage {
                image = loadedImage
                loadedURL = url
                onImageLoaded?(loadedImage)
            }
        }
    }

    nonisolated private static func cachedImage(for url: URL?, maxPixelSize: CGFloat) -> UIImage? {
        guard let url, !url.absoluteString.hasPrefix("data:") else { return nil }
        return ImageMemoryCache.shared.image(forKey: cacheKey(url, maxPixelSize))
    }

    /// Largest dimension ever displayed; originals are downsampled to this size.
    nonisolated static var maxDisplayPixelSize: CGFloat {
        CachedAsyncImageConfig.maxDisplayPixelSize
    }

    /// Full-size requests keep the bare URL (so existing callers and the
    /// `CarouselImageView` raw-URL lookup still hit); thumbnails get a size suffix.
    nonisolated static func cacheKey(_ url: URL, _ maxPixelSize: CGFloat) -> String {
        maxPixelSize == CachedAsyncImageConfig.maxDisplayPixelSize
            ? url.absoluteString
            : "\(url.absoluteString)|\(Int(maxPixelSize))"
    }

    nonisolated static func loadImage(
        from url: URL,
        maxPixelSize: CGFloat = CachedAsyncImageConfig.maxDisplayPixelSize
    ) async -> UIImage? {
        let urlString = url.absoluteString

        if urlString.hasPrefix("data:") {
            return nil
        }

        let key = cacheKey(url, maxPixelSize)
        let memoryCache = ImageMemoryCache.shared
        if let cached = memoryCache.image(forKey: key) {
            ImageAspectRatioCache.shared.recordAspectRatio(of: cached, for: urlString)
            return cached
        }

        let database = DatabaseManager.shared

        if let cachedData = try? database.cachedImageData(for: urlString),
           let cachedImage = ImageDownsampler.downsample(
               cachedData, maxPixelSize: maxPixelSize
           ) ?? UIImage(data: cachedData) {
            attachDerivedMetrics(to: cachedImage, encodedData: cachedData)
            ImageAspectRatioCache.shared.recordAspectRatio(of: cachedImage, for: urlString)
            memoryCache.setImage(cachedImage, forKey: key)
            log("Image", "Cache hit for \(urlString) (\(cachedData.count) bytes)")
            return cachedImage
        }

        log("Image", "Cache miss, downloading \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: .sakuraImage(url: url))
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            log("Image", "Downloaded \(urlString): \(data.count) bytes, HTTP \(statusCode ?? 0)")
            let downsampled = ImageDownsampler.downsample(
                data, maxPixelSize: maxPixelSize
            ) ?? UIImage(data: data)
            guard let downsampled else {
                log("Image", "Failed to decode image data from \(urlString) (\(data.count) bytes)")
                return nil
            }
            attachDerivedMetrics(to: downsampled, encodedData: data)
            ImageAspectRatioCache.shared.recordAspectRatio(of: downsampled, for: urlString)
            if memoryCache.image(forKey: key) == nil {
                try? database.cacheImageData(data, for: urlString)
            }
            memoryCache.setImage(downsampled, forKey: key)
            return downsampled
        } catch {
            log("Image", "Download failed for \(urlString): \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated private static func attachDerivedMetrics(to image: UIImage, encodedData: Data) {
        if let metricsSource = ImageDownsampler.downsample(encodedData, maxPixelSize: 64) {
            image.iconDerivedMetrics = metricsSource.ensureIconDerivedMetrics()
        } else {
            image.ensureIconDerivedMetrics()
        }
    }
}
