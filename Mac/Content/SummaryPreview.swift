import Foundation
import Hanami

/// Plain text for list previews, without the image markers and Markdown that
/// summaries are stored with.
enum SummaryPreview {

    private static let cache = NSCache<NSString, NSString>()

    static func text(for summary: String) -> String {
        if let cached = cache.object(forKey: summary as NSString) {
            return cached as String
        }
        let stripped = ContentBlock.stripMarkdown(summary)
        cache.setObject(stripped as NSString, forKey: summary as NSString)
        return stripped
    }
}
