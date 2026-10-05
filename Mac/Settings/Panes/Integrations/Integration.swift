import Hanami
import SwiftUI

enum Integration: String, CaseIterable, Identifiable {
    case webFeeds, podcasts, instagram, substack, x, youtube // swiftlint:disable:this identifier_name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .webFeeds: IntegrationText.string("Petal")
        case .podcasts: IntegrationText.string("Podcast")
        case .instagram: IntegrationText.string("Instagram")
        case .substack: IntegrationText.string("Substack")
        case .x: IntegrationText.string("X")
        case .youtube: IntegrationText.string("YouTube")
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .webFeeds: "wand.and.stars"
        case .podcasts: "headphones"
        default: "app.dashed"
        }
    }

    /// The service whose app icon stands for it; Web Feeds and Podcasts have none.
    var feedSection: FeedSection? {
        switch self {
        case .webFeeds, .podcasts: nil
        case .instagram: .instagram
        case .substack: .substack
        case .x: .x
        case .youtube: .youtube
        }
    }
}

enum IntegrationText {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "Integrations")
    }
}
