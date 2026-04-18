import SwiftUI

// MARK: - In-Memory Image Cache

/// Shared memory cache for decoded UIImages, avoiding repeated SQLite
/// lookups and Data → UIImage decoding during scroll recycling.
/// NSCache automatically evicts entries under memory pressure.
private actor ImageMemoryCache {

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

/// Holds static state for `CachedAsyncImage`.  Kept in a separate
/// non-generic type because Swift forbids stored static properties
/// inside generic types.  `nonisolated` so the nonisolated image
/// loader can read it without hopping to the main actor.
private enum CachedAsyncImageConfig {
    nonisolated static let maxDisplayPixelSize: CGFloat = 2000
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

    /// Largest dimension we ever display.  Article-detail hero images
    /// span the whole screen on iPad — 2000 px covers 2× iPad screen
    /// width, which looks identical to a full-res image at normal
    /// viewing distance.  Thumbnails in feed lists are far smaller
    /// and get downsampled further by SwiftUI on render.  The win is
    /// that a 4000×3000 photo no longer costs 48 MB of RAM per view.
    /// Computed property because generic types can't hold stored
    /// static state; the underlying constant lives on the enum above.
    nonisolated static var maxDisplayPixelSize: CGFloat {
        CachedAsyncImageConfig.maxDisplayPixelSize
    }

    nonisolated static func loadImage(from url: URL) async -> UIImage? {
        let urlString = url.absoluteString

        // Skip data: URIs - they are typically inline SVG placeholders
        // (e.g. Next.js blur-up shims) that contain no useful image content.
        if urlString.hasPrefix("data:") {
            return nil
        }

        // 1. In-memory cache (instant, no decoding)
        let memoryCache = ImageMemoryCache.shared
        if let cached = await memoryCache.image(forKey: urlString) {
            return cached
        }

        let database = DatabaseManager.shared

        // 2. Database cache (requires Data → UIImage decode via ImageIO
        // downsample so the memory cost of cached thumbnails stays
        // bounded even for originally-huge photos).
        if let cachedData = try? database.cachedImageData(for: urlString),
           let cachedImage = ImageDownsampler.downsample(
               cachedData, maxPixelSize: maxDisplayPixelSize
           ) ?? UIImage(data: cachedData) {
            await memoryCache.setImage(cachedImage, forKey: urlString)
            #if DEBUG
            debugPrint("[Image] Cache hit for \(urlString) (\(cachedData.count) bytes)")
            #endif
            return cachedImage
        }

        #if DEBUG
        debugPrint("[Image] Cache miss, downloading \(urlString)")
        #endif

        // 3. Network download — persist the original bytes to SQLite
        //    (so a bigger display context can resample if ever needed)
        //    but hold only a downsampled UIImage in memory.
        do {
            let (data, response) = try await URLSession.shared.data(for: .sakura(url: url))
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
            // Skip the SQLite write if a concurrent loader has already
            // populated the memory cache for this URL.  That task either
            // already wrote the DB row or is about to, so a second write
            // is wasted I/O on the write path.  The memory-cache check
            // is what matters - the DB copy fills itself in on any later
            // miss if the memory cache gets evicted.
            if await memoryCache.image(forKey: urlString) == nil {
                try? database.cacheImageData(data, for: urlString)
            }
            await memoryCache.setImage(downsampled, forKey: urlString)
            return downsampled
        } catch {
            #if DEBUG
            debugPrint("[Image] Download failed for \(urlString): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
