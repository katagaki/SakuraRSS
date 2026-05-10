import Foundation

public struct FeedFilterRules: Sendable {
    public let allowedKeywords: [String]
    public let keywords: [String]
    public let authors: Set<String>
}
