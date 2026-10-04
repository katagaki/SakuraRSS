import AppKit
import Hanami

/// Loads and keeps thumbnails for list rows, which are reused as they scroll.
final class RemoteImageCache {

    static let shared = RemoteImageCache()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: [(NSImage?) -> Void]] = [:]

    func cachedImage(for urlString: String) -> NSImage? {
        cache.object(forKey: urlString as NSString)
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
            let data = try? await URLSession.shared.data(for: .sakuraImage(url: url)).0
            let image = data.flatMap(NSImage.init(data:))
            if let image {
                cache.setObject(image, forKey: urlString as NSString)
            }
            let waiting = inFlight.removeValue(forKey: urlString) ?? []
            waiting.forEach { $0(image) }
        }
    }
}
