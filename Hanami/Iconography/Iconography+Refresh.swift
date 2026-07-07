import UIKit

public extension Iconography {

    func refreshAllIcons(for feeds: [Feed]) async {
        let domainEntries = feeds.map { (domain: $0.domain, siteURL: $0.siteURL as String?) }
        async let domainIcons: Void = refreshIcons(for: domainEntries)
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds {
                group.addTask {
                    await self.refetchCustomIcon(for: feed)
                }
            }
        }
        await domainIcons
    }

    private func refetchCustomIcon(for feed: Feed) async {
        switch feed.customIconURL {
        case "none":
            return
        case let customURL? where customURL != "photo":
            if let url = URL(string: customURL),
               let image = await downloadImage(from: url) {
                replaceCustomIcon(with: image, feedID: feed.id)
            }
        default:
            await refetchProviderIcon(for: feed)
        }
    }

    /// Covers feeds whose icon was prefetched from provider metadata at
    /// add time and stored as a `custom-feed-<id>` photo (X, Instagram, ...).
    private func refetchProviderIcon(for feed: Feed) async {
        guard let siteURL = URL(string: feed.siteURL),
              let provider = FeedProviderRegistry.metadataFetcher(forSiteURL: siteURL),
              let metadata = await provider.fetchMetadata(for: siteURL),
              let iconURL = metadata.iconURL,
              let image = await downloadImage(from: iconURL) else { return }
        let icon = metadata.iconNeedsSquareCrop ? image.centerSquareCropped() : image
        replaceCustomIcon(with: icon, feedID: feed.id)
    }

    /// Removes the old icon first so stale derived-metrics sidecars are not
    /// attached to the replacement image.
    private func replaceCustomIcon(with image: UIImage, feedID: Int64) {
        removeCustomIcon(feedID: feedID)
        setCustomIcon(image, feedID: feedID)
    }
}
