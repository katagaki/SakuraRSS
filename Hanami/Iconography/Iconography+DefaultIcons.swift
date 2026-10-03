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
            let bundle = Bundle(for: IconAssetBundle.self)
            #if canImport(UIKit)
            return UIImage(named: "FediverseIcon", in: bundle, compatibleWith: nil)
            #else
            return bundle.image(forResource: "FediverseIcon")
            #endif
        }
        if let appID = AppStoreFeedIcons.appID(for: feed) {
            return await appStoreIcon(appID: appID)
        }
        return await icon(for: feed.domain, siteURL: feed.siteURL)
    }
}
