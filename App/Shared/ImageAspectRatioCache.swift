import UIKit

nonisolated final class ImageAspectRatioCache: @unchecked Sendable {

    static let shared = ImageAspectRatioCache()
    private let cache = NSCache<NSString, NSNumber>()

    private init() {
        cache.countLimit = 4096
    }

    func aspectRatio(for urlString: String) -> CGFloat? {
        guard let ratio = cache.object(forKey: urlString as NSString) else { return nil }
        return CGFloat(ratio.doubleValue)
    }

    func recordAspectRatio(of image: UIImage, for urlString: String) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let ratio = Double(image.size.width / image.size.height)
        cache.setObject(NSNumber(value: ratio), forKey: urlString as NSString)
    }
}
