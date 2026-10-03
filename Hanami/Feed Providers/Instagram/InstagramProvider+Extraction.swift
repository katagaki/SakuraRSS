import Foundation

extension InstagramProvider {

    // MARK: - v1 API Item Format

    static func parseV1Item(
        item: [String: Any], username: String, displayName: String?
    ) -> ParsedInstagramPost? {
        guard let id = parseV1ItemID(from: item) else { return nil }
        guard let code = item["code"] as? String, !code.isEmpty else { return nil }

        var captionText = ""
        if let caption = item["caption"] as? [String: Any],
           let text = caption["text"] as? String {
            captionText = text
        }

        let (imageURL, carouselImageURLs) = parseV1ItemImages(from: item)

        var publishedDate: Date?
        if let timestamp = item["taken_at"] as? TimeInterval {
            publishedDate = Date(timeIntervalSince1970: timestamp)
        }

        let isReel = (item["product_type"] as? String) == "clips"
        let pathSegment = isReel ? "reel" : "p"
        let postURL = "https://www.instagram.com/\(pathSegment)/\(code)/"
        let authorName = displayName ?? username

        return ParsedInstagramPost(
            id: id,
            text: captionText,
            author: authorName,
            authorHandle: username,
            url: postURL,
            imageURL: imageURL,
            carouselImageURLs: carouselImageURLs,
            publishedDate: publishedDate
        )
    }

    private static func parseV1ItemID(from item: [String: Any]) -> String? {
        let identifier: String
        if let idStr = item["id"] as? String {
            identifier = idStr
        } else if let primaryKey = item["pk"] as? Int64 {
            identifier = String(primaryKey)
        } else if let primaryKey = item["pk"] as? String {
            identifier = primaryKey
        } else {
            return nil
        }
        return identifier.isEmpty ? nil : identifier
    }

    private static func parseV1ItemImages(
        from item: [String: Any]
    ) -> (imageURL: String?, carouselImageURLs: [String]) {
        var carouselImageURLs: [String] = []
        var imageURL: String?
        if let carouselMedia = item["carousel_media"] as? [[String: Any]] {
            for media in carouselMedia {
                if let url = bestImageURL(from: media) {
                    carouselImageURLs.append(url)
                }
            }
            imageURL = carouselImageURLs.first
        }
        if imageURL == nil {
            imageURL = bestImageURL(from: item)
        }
        return (imageURL, carouselImageURLs)
    }

    private static func bestImageURL(from item: [String: Any]) -> String? {
        if let imageVersions = item["image_versions2"] as? [String: Any],
           let candidates = imageVersions["candidates"] as? [[String: Any]] {
            let sorted = candidates.sorted {
                ($0["width"] as? Int ?? 0) > ($1["width"] as? Int ?? 0)
            }
            if let best = sorted.first, let url = best["url"] as? String {
                return url
            }
        }
        return item["display_url"] as? String
            ?? item["thumbnail_src"] as? String
            ?? item["image_url"] as? String
    }
}
