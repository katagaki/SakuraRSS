import Foundation

extension RedditPostScraper {

    /// Walks a decoded `/comments/{id}.json` listings array and produces a
    /// `RedditPostFetchResult`. Reddit returns an array of two listings —
    /// the first contains the post itself, the second contains comments
    /// (which the reader intentionally ignores).
    static func extractResult(fromListings listings: [Any]) throws -> RedditPostFetchResult {
        guard let firstListing = listings.first as? [String: Any],
              let data = firstListing["data"] as? [String: Any],
              let children = data["children"] as? [[String: Any]],
              let postWrapper = children.first,
              let post = postWrapper["data"] as? [String: Any] else {
            throw RedditPostScraperError.parseFailed
        }

        return extractResult(fromPost: post)
    }

    /// Translates a single Reddit post payload into a renderable result.
    /// Follows the priority order documented in the plan: crosspost parent,
    /// gallery, native video, image hint, self text, off-reddit link,
    /// unknown fallback.
    static func extractResult(fromPost post: [String: Any]) -> RedditPostFetchResult {
        // 1. Crossposts — recurse into the parent post so the reader sees the
        //    original content type rather than a wrapper.
        if let parents = post["crosspost_parent_list"] as? [[String: Any]],
           let parent = parents.first {
            return extractResult(fromPost: parent)
        }

        let isGallery = (post["is_gallery"] as? Bool) ?? false
        let isVideo = (post["is_video"] as? Bool) ?? false
        let isSelf = (post["is_self"] as? Bool) ?? false
        let postHint = post["post_hint"] as? String

        // Selftext is prepended to any media that follows so readers get the
        // author's prose alongside the images/video in one scrollable flow.
        let selftext: String = {
            guard let raw = post["selftext"] as? String else { return "" }
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        var markerLines: [String] = []
        if !selftext.isEmpty {
            markerLines.append(selftext)
        }

        // 2. Gallery — emit one {{IMG}} line per gallery item.
        if isGallery, let galleryURLs = galleryImageURLs(from: post), !galleryURLs.isEmpty {
            for galleryURL in galleryURLs {
                markerLines.append("{{IMG}}\(galleryURL){{/IMG}}")
            }
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        // 3. Native v.redd.it video — emit an HLS URL.
        if isVideo, let media = post["media"] as? [String: Any],
           let redditVideo = media["reddit_video"] as? [String: Any],
           let hls = redditVideo["hls_url"] as? String,
           !hls.isEmpty {
            markerLines.append("{{VIDEO}}\(unescapeHTMLEntities(hls)){{/VIDEO}}")
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        // 4. Single image hint — emit the image URL directly.
        if postHint == "image", let urlString = post["url"] as? String,
           let imageURL = URL(string: unescapeHTMLEntities(urlString)) {
            markerLines.append("{{IMG}}\(imageURL.absoluteString){{/IMG}}")
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        // 5. Pure self post — we already captured selftext above.
        if isSelf {
            if markerLines.isEmpty {
                return .markerString("")
            }
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        // 6. Off-reddit link — short-circuit to the generic extractor.
        if let urlString = post["url"] as? String,
           let linkedURL = URL(string: unescapeHTMLEntities(urlString)),
           let host = linkedURL.host?.lowercased(),
           host != "reddit.com",
           !host.hasSuffix(".reddit.com") {
            return .linkedArticle(linkedURL)
        }

        // 7. Unknown shape — fall back to any selftext we have, or an empty
        //    string (the caller will still have the RSS summary to show).
        return .markerString(markerLines.joined(separator: "\n\n"))
    }

    // MARK: - Helpers

    /// Resolves gallery item IDs into absolute image URLs by looking them up
    /// in `media_metadata`. Reddit returns the `s.u` URL HTML-escaped with
    /// `&amp;`, so we unescape to make them usable.
    private static func galleryImageURLs(from post: [String: Any]) -> [String]? {
        guard let galleryData = post["gallery_data"] as? [String: Any],
              let items = galleryData["items"] as? [[String: Any]],
              let mediaMetadata = post["media_metadata"] as? [String: Any] else {
            return nil
        }

        var urls: [String] = []
        for item in items {
            guard let mediaID = item["media_id"] as? String,
                  let entry = mediaMetadata[mediaID] as? [String: Any],
                  let source = entry["s"] as? [String: Any] else {
                continue
            }
            if let urlString = source["u"] as? String {
                urls.append(unescapeHTMLEntities(urlString))
            } else if let gif = source["gif"] as? String {
                urls.append(unescapeHTMLEntities(gif))
            }
        }
        return urls
    }

    /// Reddit JSON returns image URLs with `&amp;` in the query string even
    /// with `raw_json=1` in some endpoints. Normalize them back to `&` so
    /// URLSession fetches succeed.
    private static func unescapeHTMLEntities(_ input: String) -> String {
        input.replacingOccurrences(of: "&amp;", with: "&")
    }
}
