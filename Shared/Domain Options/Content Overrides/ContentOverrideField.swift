import Foundation

/// RSS element a feed-level Content Override can swap into title/body/author.
nonisolated enum ContentOverrideField: String, CaseIterable, Sendable {
    case `default`
    case title
    case summary
    case content
    case author

    var localizedName: String {
        switch self {
        case .default: String(localized: "FeedEdit.ContentOverrides.Field.Default", table: "Feeds")
        case .title: String(localized: "FeedEdit.ContentOverrides.Field.Title", table: "Feeds")
        case .summary: String(localized: "FeedEdit.ContentOverrides.Field.Summary", table: "Feeds")
        case .content: String(localized: "FeedEdit.ContentOverrides.Field.Content", table: "Feeds")
        case .author: String(localized: "FeedEdit.ContentOverrides.Field.Author", table: "Feeds")
        }
    }
}
