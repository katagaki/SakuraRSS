import Foundation

extension RedditProvider {

    static func extractListingResult(from json: Any) -> RedditListingFetchResult {
        guard let root = json as? [String: Any],
              let data = root["data"] as? [String: Any],
              let children = data["children"] as? [[String: Any]] else {
            return RedditListingFetchResult(imagesByPostID: [:])
        }

        var map: [String: String] = [:]
        for child in children {
            guard let post = child["data"] as? [String: Any],
                  let postID = post["id"] as? String, !postID.isEmpty else {
                continue
            }
            if let imageURL = bestListingImageURL(from: post) {
                map[postID] = imageURL
            }
        }
        return RedditListingFetchResult(imagesByPostID: map)
    }

    /// Best still image for a post: preview source, then gallery, then
    /// the `thumbnail` field if it's an actual URL.
    static func bestListingImageURL(from post: [String: Any]) -> String? {
        if let url = listingPreviewImageURL(from: post) {
            return url
        }
        if let url = listingGalleryImageURL(from: post) {
            return url
        }
        if let thumbnail = post["thumbnail"] as? String,
           thumbnail.hasPrefix("http://") || thumbnail.hasPrefix("https://") {
            return thumbnail
        }
        return nil
    }

    private static func listingPreviewImageURL(from post: [String: Any]) -> String? {
        guard let preview = post["preview"] as? [String: Any],
              let images = preview["images"] as? [[String: Any]],
              let first = images.first,
              let source = first["source"] as? [String: Any],
              let urlString = source["url"] as? String,
              !urlString.isEmpty else {
            return nil
        }
        return unescapeAmpersand(urlString)
    }

    private static func listingGalleryImageURL(from post: [String: Any]) -> String? {
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
            return unescapeAmpersand(urlString)
        }
        if let gif = source["gif"] as? String, !gif.isEmpty {
            return unescapeAmpersand(gif)
        }
        return nil
    }
}
