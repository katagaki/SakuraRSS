import UIKit

extension FaviconCache {

    /// Checks whether the domain's feeds represent unique profiles that use og:image as favicon.
    static func isProfileBasedDomain(_ domain: String) -> Bool {
        let host = domain.lowercased()
        if host.contains("youtube.com") || host.contains("youtu.be") { return true }
        if host == "bsky.app" || host.hasSuffix(".bsky.app") { return true }
        if host == "reddit.com" || host.hasSuffix(".reddit.com") { return true }
        if host == "note.com" || host.hasSuffix(".note.com") { return true }
        if SubstackPublicationFetcher.isSubstackPublicationHost(host) { return true }
        if DisplayStyleFeedDomains.shouldPreferFeedView(feedDomain: host) { return true }
        return false
    }

    /// Detects profile-based feeds including unlisted Mastodon instances.
    static func isProfileBased(domain: String, siteURL: String?) -> Bool {
        if isProfileBasedDomain(domain) { return true }
        if let siteURL, let url = URL(string: siteURL), url.path.hasPrefix("/@") {
            return true
        }
        return false
    }

    /// Downloads an image at `url` via the favicon cache's URL session.
    nonisolated func downloadImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await Self.urlSession.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    /// Resolves a profile/publication avatar by dispatching through the
    /// `MetadataFetchingProvider` registry, falling back to a generic
    /// `og:image` scrape.
    nonisolated func fetchProfileAvatar(from siteURL: String) async -> UIImage? {
        guard let url = URL(string: siteURL) else { return nil }

        if let provider = FeedProviderRegistry.metadataFetcher(forSiteURL: url) {
            let metadata = await provider.fetchMetadata(for: url)
            if let iconURL = metadata?.iconURL {
                if let image = await downloadImage(from: iconURL) {
                    #if DEBUG
                    debugPrint("[Favicon] profile avatar: downloaded \(iconURL) for \(siteURL)")
                    #endif
                    if metadata?.iconNeedsSquareCrop == true {
                        return image.centerSquareCropped()
                    }
                    return image
                }
                #if DEBUG
                debugPrint("[Favicon] profile avatar: download FAILED for \(iconURL) (\(siteURL))")
                #endif
            } else {
                #if DEBUG
                debugPrint("[Favicon] profile avatar: provider returned no iconURL for \(siteURL)")
                #endif
            }
            if let fallback = provider.fallbackIconURL,
               let image = await downloadImage(from: fallback) {
                #if DEBUG
                debugPrint("[Favicon] profile avatar: using brand fallback \(fallback) for \(siteURL)")
                #endif
                return image
            }
        }

        do {
            let (data, _) = try await Self.urlSession.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            guard let imageURL = extractMetaContent(from: html, property: "og:image"),
                  let avatarURL = URL(string: imageURL) else { return nil }

            return await downloadImage(from: avatarURL)
        } catch {
            return nil
        }
    }
}
