import Foundation

struct FeedFilterRules: Sendable {
    let allowedKeywords: [String]
    let keywords: [String]
    let authors: Set<String>
}
