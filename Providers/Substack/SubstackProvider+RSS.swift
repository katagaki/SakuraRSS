import Foundation

extension SubstackProvider: RSSFeedProvider {

    nonisolated static var providerID: String { "substack" }

    nonisolated static var domains: Set<String> { ["substack.com"] }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isSubstackFeedURL(feedURL)
    }
}
