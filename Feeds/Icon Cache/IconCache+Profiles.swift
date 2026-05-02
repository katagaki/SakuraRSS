import UIKit

extension IconCache {

    /// Checks whether the domain's feeds represent unique profiles that use og:image as icon.
    static func isProfileBasedDomain(_ domain: String) -> Bool {
        let host = domain.lowercased()
        if host.contains("youtube.com") || host.contains("youtu.be") { return true }
        if host == "bsky.app" || host.hasSuffix(".bsky.app") { return true }
        if host == "reddit.com" || host.hasSuffix(".reddit.com") { return true }
        if host == "note.com" || host.hasSuffix(".note.com") { return true }
        if SubstackPublicationFetcher.isSubstackPublicationHost(host) { return true }
        if PixelfedProfileFetcher.isPixelfedHost(host) { return true }
        if DisplayStyleSetDomains.style(for: host) == .feed { return true }
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

    /// Downloads an image at `url` via the icon cache's URL session.
    nonisolated func downloadImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await Self.urlSession.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    /// Resolves a profile/publication avatar by dispatching through the
    /// `MetadataFetchingProvider` registry, falling back to a generic
    /// `og:image` scrape.
    nonisolated func fetchProfileAvatar(from siteURL: String) async -> UIImage? {
        guard let url = URL(string: siteURL) else {
            log("Icon", "profile avatar: bad siteURL \(siteURL)")
            return nil
        }

        if let provider = FeedProviderRegistry.metadataFetcher(forSiteURL: url) {
            log("Icon", "profile avatar: provider=\(provider.providerID) siteURL=\(siteURL)")
            let metadata = await provider.fetchMetadata(for: url)
            if let iconURL = metadata?.iconURL {
                if let image = await downloadImage(from: iconURL) {
                    log("Icon", "profile avatar: downloaded \(iconURL) for \(siteURL)")
                    if metadata?.iconNeedsSquareCrop == true {
                        return image.centerSquareCropped()
                    }
                    return image
                }
                log("Icon", "profile avatar: download FAILED for \(iconURL) (\(siteURL))")
            } else {
                log("Icon", "profile avatar: provider returned no iconURL for \(siteURL)")
            }
            if let fallback = provider.fallbackIconURL,
               let image = await downloadImage(from: fallback) {
                log("Icon", "profile avatar: using brand fallback \(fallback) for \(siteURL)")
                return image
            }
        } else {
            log("Icon", "profile avatar: no provider matched siteURL=\(siteURL); falling through to og:image")
        }

        do {
            let (data, _) = try await Self.urlSession.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                log("Icon", "profile avatar: og:image fallback non-utf8 body for \(siteURL)")
                return nil
            }

            guard let imageURL = extractMetaContent(from: html, property: "og:image"),
                  let avatarURL = URL(string: imageURL) else {
                log("Icon", "profile avatar: og:image fallback found no meta for \(siteURL)")
                return nil
            }

            log("Icon", "profile avatar: og:image fallback \(avatarURL) for \(siteURL)")
            return await downloadImage(from: avatarURL)
        } catch {
            log("Icon", "profile avatar: og:image fallback fetch error \(error.localizedDescription) for \(siteURL)")
            return nil
        }
    }
}
