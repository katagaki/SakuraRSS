import Foundation

/// A feed source with stable identity and feed-URL recognition.
protocol FeedProvider {

    nonisolated static var providerID: String { get }

    /// `UserDefaults` Bool key gating the provider; `nil` if always on.
    nonisolated static var enabledFlagKey: String? { get }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool
}

extension FeedProvider {

    nonisolated static var enabledFlagKey: String? { nil }

    nonisolated static var isEnabled: Bool {
        guard let key = enabledFlagKey else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}
