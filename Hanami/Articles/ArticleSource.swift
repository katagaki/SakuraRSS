import Foundation

public nonisolated enum ArticleSource: String, CaseIterable, Sendable {
    case automatic
    case fetchText
    case extractText
    case feedText
}
