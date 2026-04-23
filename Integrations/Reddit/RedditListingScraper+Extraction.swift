import Foundation

extension RedditListingScraper {

    static func extractResult(from json: Any) -> RedditListingScrapeResult {
        guard let root = json as? [String: Any],
              let data = root["data"] as? [String: Any],
              let children = data["children"] as? [[String: Any]] else {
            return RedditListingScrapeResult(imagesByPostID: [:])
        }

        var map: [String: String] = [:]
        for child in children {
            guard let post = child["data"] as? [String: Any],
                  let postID = post["id"] as? String, !postID.isEmpty else {
                continue
            }
            if let imageURL = bestImageURL(from: post) {
                map[postID] = imageURL
            }
        }
        return RedditListingScrapeResult(imagesByPostID: map)
    }

    /// Picks the highest-quality still image that Reddit exposes for a post.
    /// Prefers the full-resolution preview, then gallery metadata, then the
    /// thumbnail field if it happens to be a URL rather than a placeholder
    /// sentinel like `self` / `default` / `nsfw`.
    static func bestImageURL(from post: [String: Any]) -> String? {
        if let url = previewImageURL(from: post) {
            return url
        }
        if let url = galleryImageURL(from: post) {
            return url
        }
        if let thumbnail = post["thumbnail"] as? String,
           thumbnail.hasPrefix("http://") || thumbnail.hasPrefix("https://") {
            return thumbnail
        }
        return nil
    }

    private static func previewImageURL(from post: [String: Any]) -> String? {
        guard let preview = post["preview"] as? [String: Any],
              let images = preview["images"] as? [[String: Any]],
              let first = images.first,
              let source = first["source"] as? [String: Any],
              let urlString = source["url"] as? String,
              !urlString.isEmpty else {
            return nil
        }
        return unescapeHTMLEntities(urlString)
    }

    private static func galleryImageURL(from post: [String: Any]) -> String? {
        guard let galleryData = post["gallery_data"] as? [String: Any],
              let items = galleryData["items"] as? [[String: Any]],
              let firstItem = items.first,
              let mediaID = firstItem["media_id"] as? String,
              let metadata = post["media_metadata"] as? [String: Any],
              let entry = metadata[mediaID] as? [String: Any],
              let source = entry["s"] as? [String: Any] else {
            return nil
        }
        if let urlString = source["u"] as? String, !urlString.isEmpty {
            return unescapeHTMLEntities(urlString)
        }
        if let gif = source["gif"] as? String, !gif.isEmpty {
            return unescapeHTMLEntities(gif)
        }
        return nil
    }

    private static func unescapeHTMLEntities(_ input: String) -> String {
        input.replacingOccurrences(of: "&amp;", with: "&")
    }
}
