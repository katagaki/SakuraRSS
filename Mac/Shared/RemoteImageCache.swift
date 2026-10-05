import AppKit
import Hanami

/// Loads and keeps thumbnails for list rows, which are reused as they scroll.
final class RemoteImageCache {

    static let shared = RemoteImageCache()

    private static let maxPixelSize: CGFloat = 1200

    private var inFlight: [String: [(NSImage?) -> Void]] = [:]

    func cachedImage(for urlString: String) -> NSImage? {
        URL(string: urlString).flatMap { CachedImageData.cachedImage($0, maxPixelSize: Self.maxPixelSize) }
    }

    func image(for urlString: String, completion: @escaping (NSImage?) -> Void) {
        if let cached = cachedImage(for: urlString) {
            completion(cached)
            return
        }
        if inFlight[urlString] != nil {
            inFlight[urlString]?.append(completion)
            return
        }
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        inFlight[urlString] = [completion]
        Task {
            let image = await CachedImageData.image(url, maxPixelSize: Self.maxPixelSize)
            let waiting = inFlight.removeValue(forKey: urlString) ?? []
            waiting.forEach { $0(image) }
        }
    }
}
