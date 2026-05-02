import Foundation

nonisolated enum ParserVersion {
    /// Bump this integer whenever ArticleExtractor logic changes
    /// to invalidate all cached article content on next launch.
    static let articleExtractor = 17
}
