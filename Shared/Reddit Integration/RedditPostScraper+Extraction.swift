import Foundation

extension RedditPostScraper {

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

    static func extractResult(fromPost post: [String: Any]) -> RedditPostFetchResult {
        if let parents = post["crosspost_parent_list"] as? [[String: Any]],
           let parent = parents.first {
            return extractResult(fromPost: parent)
        }

        let isGallery = (post["is_gallery"] as? Bool) ?? false
        let isVideo = (post["is_video"] as? Bool) ?? false
        let isSelf = (post["is_self"] as? Bool) ?? false
        let postHint = post["post_hint"] as? String

        let selftext: String = {
            guard let raw = post["selftext"] as? String else { return "" }
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        var markerLines: [String] = []
        if !selftext.isEmpty {
            markerLines.append(selftext)
        }

        if isGallery, let galleryURLs = galleryImageURLs(from: post), !galleryURLs.isEmpty {
            for galleryURL in galleryURLs {
                markerLines.append("{{IMG}}\(galleryURL){{/IMG}}")
            }
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        if isVideo, let media = post["media"] as? [String: Any],
           let redditVideo = media["reddit_video"] as? [String: Any],
           let hls = redditVideo["hls_url"] as? String,
           !hls.isEmpty {
            markerLines.append("{{VIDEO}}\(unescapeHTMLEntities(hls)){{/VIDEO}}")
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        if postHint == "image", let urlString = post["url"] as? String,
           let imageURL = URL(string: unescapeHTMLEntities(urlString)) {
            markerLines.append("{{IMG}}\(imageURL.absoluteString){{/IMG}}")
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        if isSelf {
            if markerLines.isEmpty {
                return .markerString("")
            }
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        if let urlString = post["url"] as? String,
           let linkedURL = URL(string: unescapeHTMLEntities(urlString)),
           let host = linkedURL.host?.lowercased(),
           host != "reddit.com",
           !host.hasSuffix(".reddit.com") {
            return .linkedArticle(linkedURL)
        }

        return .markerString(markerLines.joined(separator: "\n\n"))
    }

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

    private static func unescapeHTMLEntities(_ input: String) -> String {
        input.replacingOccurrences(of: "&amp;", with: "&")
    }
}
