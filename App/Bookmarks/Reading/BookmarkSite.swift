import SwiftUI
import Hanami

/// Stands in for the feed of a bookmark saved from outside the app, so rows
/// that label and decorate content by its feed have a name and icon to show.
enum BookmarkSite {

    static func name(of article: Article) -> String? {
        URL(string: article.url)?.host()
    }

    static func icon(for article: Article) async -> PlatformImage? {
        guard let host = name(of: article) else { return nil }
        let siteURL = AppStoreFeedIcons.appID(for: host) == nil ? article.url : nil
        return await Iconography.shared.icon(for: host, siteURL: siteURL)
    }
}
