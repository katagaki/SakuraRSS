import Foundation

public struct InstagramProfileFetchResult: Sendable {
    public let posts: [ParsedInstagramPost]
    public let profileImageURL: String?
    public let displayName: String?
}
