import Foundation

extension SubstackProvider: RSSFeedProvider {

    public nonisolated static var providerID: String { "substack" }

    public nonisolated static var domains: Set<String> { ["substack.com"] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isSubstackFeedURL(feedURL)
    }
}
