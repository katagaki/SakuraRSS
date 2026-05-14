import Foundation

public extension BlueskyProvider {

    nonisolated static let authorFeedLimit = 50

    /// Fetches the author's recent posts via `app.bsky.feed.getAuthorFeed`,
    /// skipping replies (via filter) and reposts (skipped in code).
    func fetchAuthorFeed(handle: String) async -> BlueskyFeedFetchResult {
        let empty = BlueskyFeedFetchResult(posts: [], displayName: nil, profileImageURL: nil)
        guard let did = await Self.resolveDID(forHandle: handle) ?? handle.asDIDIfValid else {
            return empty
        }
        let posts = await Self.fetchAuthorFeedPosts(actor: did)
        if let firstAuthor = posts.first {
            return BlueskyFeedFetchResult(
                posts: posts,
                displayName: firstAuthor.author.isEmpty ? nil : firstAuthor.author,
                profileImageURL: nil
            )
        }
        // Empty feed: fall back to getProfile so the feed row still gets a name/avatar.
        let profile = await Self.fetchActorProfile(actor: did)
        return BlueskyFeedFetchResult(
            posts: [],
            displayName: profile?.displayName,
            profileImageURL: profile?.profileImageURL
        )
    }

    // MARK: - getAuthorFeed

    nonisolated static func fetchAuthorFeedPosts(actor: String) async -> [ParsedBlueskyPost] {
        guard var components = URLComponents(
            string: "https://\(publicAPIHost)/xrpc/app.bsky.feed.getAuthorFeed"
        ) else { return [] }
        components.queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: String(authorFeedLimit)),
            URLQueryItem(name: "filter", value: "posts_no_replies")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let feed = root["feed"] as? [[String: Any]] else { return [] }
            return feed.compactMap { parseFeedViewPost($0) }
        } catch {
            log("BlueskyFeed", "getAuthorFeed failed - \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - JSON parsing

    nonisolated static func parseFeedViewPost(_ entry: [String: Any]) -> ParsedBlueskyPost? {
        if let reason = entry["reason"] as? [String: Any],
           (reason["$type"] as? String) == "app.bsky.feed.defs#reasonRepost" {
            return nil
        }
        guard let post = entry["post"] as? [String: Any],
              let uri = post["uri"] as? String,
              let record = post["record"] as? [String: Any],
              let author = post["author"] as? [String: Any],
              let authorHandle = author["handle"] as? String else { return nil }

        guard let postURL = postWebURL(atURI: uri, authorHandle: authorHandle) else { return nil }

        let text = (record["text"] as? String) ?? ""
        let displayName = (author["displayName"] as? String) ?? ""
        let createdAt = (record["createdAt"] as? String).flatMap(parseISO8601(_:))
        let embed = post["embed"] as? [String: Any]

        let media = extractMedia(from: embed)

        return ParsedBlueskyPost(
            uri: uri,
            url: postURL,
            text: text,
            author: displayName,
            authorHandle: authorHandle,
            images: media.images,
            videoThumbnailURL: media.videoThumbnailURL,
            publishedDate: createdAt
        )
    }

    // MARK: - Embed extraction

    private nonisolated static func extractMedia(
        from embed: [String: Any]?
    ) -> (images: [ParsedBlueskyImage], videoThumbnailURL: String?) {
        guard let embed else { return ([], nil) }
        let type = (embed["$type"] as? String) ?? ""

        switch type {
        case "app.bsky.embed.images#view":
            return (parseImages(from: embed), nil)
        case "app.bsky.embed.video#view":
            return ([], embed["thumbnail"] as? String)
        case "app.bsky.embed.recordWithMedia#view":
            guard let media = embed["media"] as? [String: Any] else { return ([], nil) }
            let mediaType = (media["$type"] as? String) ?? ""
            if mediaType == "app.bsky.embed.images#view" {
                return (parseImages(from: media), nil)
            }
            if mediaType == "app.bsky.embed.video#view" {
                return ([], media["thumbnail"] as? String)
            }
            return ([], nil)
        default:
            return ([], nil)
        }
    }

    private nonisolated static func parseImages(from view: [String: Any]) -> [ParsedBlueskyImage] {
        guard let images = view["images"] as? [[String: Any]] else { return [] }
        return images.compactMap { image in
            guard let thumb = image["thumb"] as? String,
                  let fullsize = image["fullsize"] as? String else { return nil }
            let alt = (image["alt"] as? String) ?? ""
            return ParsedBlueskyImage(thumbURL: thumb, fullsizeURL: fullsize, alt: alt)
        }
    }

    // MARK: - URL & date helpers

    /// Builds the human-readable post URL `https://bsky.app/profile/{handle}/post/{rkey}`
    /// from the AT URI `at://{did}/app.bsky.feed.post/{rkey}`.
    private nonisolated static func postWebURL(atURI: String, authorHandle: String) -> String? {
        guard let rkey = atURI.split(separator: "/").last, !rkey.isEmpty else { return nil }
        return "https://\(host)/profile/\(authorHandle)/post/\(rkey)"
    }

    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private nonisolated static func parseISO8601(_ value: String) -> Date? {
        iso8601Formatter.date(from: value) ?? iso8601FallbackFormatter.date(from: value)
    }
}
