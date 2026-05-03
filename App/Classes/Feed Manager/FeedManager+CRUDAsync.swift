import Foundation
import UIKit

extension FeedManager {

    /// Async variant of `addFeed(url:title:siteURL:...)` that pre-fetches
    /// provider-specific metadata (display name, profile photo) before
    /// inserting so the feed appears in the list with its final title and
    /// icon, rather than briefly showing a handle placeholder.
    @discardableResult
    func addFeedFetchingMetadata(
        url: String,
        title: String,
        siteURL: String,
        description: String = "",
        category: String? = nil,
        isPodcast: Bool = false
    ) async throws -> Feed? {
        guard !database.feedExists(url: url) else {
            throw FeedError.alreadyExists
        }
        let newHost = URL(string: siteURL)?.host
            ?? URL(string: url)?.host
            ?? ""
        if let key = FollowLimitSetDomains.limitKey(for: newHost),
           let limit = FollowLimitSetDomains.limits[key] {
            let current = feeds.filter { existing in
                FollowLimitSetDomains.limitKey(for: existing.domain) == key
            }.count
            if current >= limit {
                throw FeedError.followLimitExceeded(host: key, limit: limit)
            }
        }

        let prefetched = await prefetchAddFeedMetadata(siteURL: siteURL)
        let resolvedTitle: String
        if let displayName = prefetched.displayName,
           !displayName.isEmpty {
            resolvedTitle = displayName
        } else {
            resolvedTitle = title
        }

        let feedID = try database.insertFeed(
            title: resolvedTitle, url: url, siteURL: siteURL,
            description: description, iconURL: nil,
            category: category, isPodcast: isPodcast
        )

        if let image = prefetched.iconImage {
            await IconCache.shared.setCustomIcon(image, feedID: feedID)
            try? database.updateFeedDetails(
                id: feedID, title: resolvedTitle, url: url,
                customIconURL: "photo",
                isTitleCustomized: false
            )
            await MainActor.run { self.notifyIconChange() }
        }
        generateAcronymIcon(feedID: feedID, title: resolvedTitle)

        let newFeed = try? database.feed(byID: feedID)
        await loadFromDatabaseInBackground()
        if let newFeed {
            Task {
                try? await refreshFeed(newFeed)
            }
        }
        return newFeed
    }

    private struct PrefetchedAddFeedMetadata {
        let displayName: String?
        let iconImage: UIImage?
    }

    private func prefetchAddFeedMetadata(
        siteURL: String
    ) async -> PrefetchedAddFeedMetadata {
        guard let url = URL(string: siteURL),
              let provider = FeedProviderRegistry.metadataFetcher(forSiteURL: url),
              let metadata = await provider.fetchMetadata(for: url) else {
            return PrefetchedAddFeedMetadata(displayName: nil, iconImage: nil)
        }

        var image: UIImage?
        if let iconURL = metadata.iconURL,
           let (data, _) = try? await IconCache.urlSession.data(from: iconURL),
           let downloaded = UIImage(data: data) {
            image = metadata.iconNeedsSquareCrop
                ? downloaded.centerSquareCropped()
                : downloaded
        }
        return PrefetchedAddFeedMetadata(
            displayName: metadata.displayName,
            iconImage: image
        )
    }
}
