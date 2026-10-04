import Hanami
import SwiftUI

enum Integration: String, CaseIterable, Identifiable {
    case webFeeds, instagram, substack, x, youtube // swiftlint:disable:this identifier_name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .webFeeds: IntegrationText.string("Petal")
        case .instagram: IntegrationText.string("Instagram")
        case .substack: IntegrationText.string("Substack")
        case .x: IntegrationText.string("X")
        case .youtube: IntegrationText.string("YouTube")
        }
    }

    /// The service whose app icon stands for it; Web Feeds has none.
    var feedSection: FeedSection? {
        switch self {
        case .webFeeds: nil
        case .instagram: .instagram
        case .substack: .substack
        case .x: .x
        case .youtube: .youtube
        }
    }
}

enum IntegrationText {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "Integrations")
    }
}
