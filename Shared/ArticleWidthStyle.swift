import Foundation

nonisolated enum ArticleWidthStyle: String, CaseIterable, Sendable {
    case `default`
    case fullWidth

    static let storageKey = "Display.ArticleWidthStyle"
}
