import Foundation

/// Per-feed content override: which RSS element feeds the title, body, and author.
nonisolated struct ContentOverride: Sendable, Hashable {
    let feedID: Int64
    var enabled: Bool
    var titleField: ContentOverrideField
    var bodyField: ContentOverrideField
    var authorField: ContentOverrideField

    static func disabled(feedID: Int64) -> ContentOverride {
        ContentOverride(
            feedID: feedID,
            enabled: false,
            titleField: .default,
            bodyField: .default,
            authorField: .default
        )
    }

    var isActive: Bool {
        enabled && (titleField != .default || bodyField != .default || authorField != .default)
    }
}
