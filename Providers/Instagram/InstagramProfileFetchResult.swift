import Foundation

struct InstagramProfileFetchResult: Sendable {
    let posts: [ParsedInstagramPost]
    let profileImageURL: String?
    let displayName: String?
}
