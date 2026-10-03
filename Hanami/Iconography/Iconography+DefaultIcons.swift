import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

private nonisolated final class IconAssetBundle {}

public extension Iconography {
    func defaultIcon(for feed: Feed) async -> PlatformImage? {
        if feed.isFediverseFeed {
            return fediverseIcon()
        }
        if let appID = AppStoreFeedIcons.appID(for: feed) {
            return await appStoreIcon(appID: appID)
        }
        return await icon(for: feed.domain, siteURL: feed.siteURL)
    }

    func icon(for section: FeedSection) async -> PlatformImage? {
        let domain: String
        switch section {
        case .bluesky: domain = "bsky.app"
        case .instagram: return await appStoreIcon(appID: 389801252)
        case .note: domain = "note.com"
        case .reddit: domain = "reddit.com"
        case .substack: domain = "substack.com"
        case .x: domain = "x.com"
        case .youtube: return await appStoreIcon(appID: 544007664)
        case .fediverse: return fediverseIcon()
        case .feeds, .podcasts, .vimeo, .niconico: return nil
        }
        return await icon(for: domain)
    }

    private func fediverseIcon() -> PlatformImage? {
        let bundle = Bundle(for: IconAssetBundle.self)
        #if canImport(UIKit)
        return UIImage(named: "FediverseIcon", in: bundle, compatibleWith: nil)
        #else
        return bundle.image(forResource: "FediverseIcon")
        #endif
    }
}
