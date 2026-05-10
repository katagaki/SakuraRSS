import Foundation

/// Per-feed content override: which RSS element feeds the title, body, and author.
public nonisolated struct ContentOverride: Sendable, Hashable {
    public let feedID: Int64
    public var enabled: Bool
    public var titleField: ContentOverrideField
    public var bodyField: ContentOverrideField
    public var authorField: ContentOverrideField

    public init(
        feedID: Int64,
        enabled: Bool,
        titleField: ContentOverrideField,
        bodyField: ContentOverrideField,
        authorField: ContentOverrideField
    ) {
        self.feedID = feedID
        self.enabled = enabled
        self.titleField = titleField
        self.bodyField = bodyField
        self.authorField = authorField
    }

    public static func disabled(feedID: Int64) -> ContentOverride {
        ContentOverride(
            feedID: feedID,
            enabled: false,
            titleField: .default,
            bodyField: .default,
            authorField: .default
        )
    }

    public var hasCustomization: Bool {
        titleField != .default || bodyField != .default || authorField != .default
    }

    public var isActive: Bool {
        enabled && hasCustomization
    }
}
