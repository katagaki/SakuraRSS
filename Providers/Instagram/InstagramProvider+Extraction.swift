import Foundation

// MARK: - Response Parsing

extension InstagramProvider {

    // swiftlint:disable:next cyclomatic_complexity
    static func parseProfileResponse(
        data: Data, username: String
    ) -> InstagramProfileFetchResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any] else {
            log("InstagramProvider", "Failed to parse profile JSON structure")
            return nil
        }

        let displayName = user["full_name"] as? String
        let profileImageURL = user["profile_pic_url_hd"] as? String
            ?? user["profile_pic_url"] as? String

        let mediaKeys = user.keys.filter {
            $0.contains("media") || $0.contains("edge") || $0.contains("timeline")
        }
        log("InstagramProvider", "User keys containing media/edge/timeline: \(mediaKeys)")

        var posts: [ParsedInstagramPost] = []

        if let edgeMedia = user["edge_owner_to_timeline_media"] as? [String: Any],
           let edges = edgeMedia["edges"] as? [[String: Any]] {
            for edge in edges {
                guard let node = edge["node"] as? [String: Any] else { continue }
                if let post = parseEdgeNode(node: node, username: username,
                                            displayName: displayName) {
                    posts.append(post)
                }
            }
        }

        if posts.isEmpty, let edgeMedia = user["edge_owner_to_timeline_media"] as? [String: Any] {
            if let items = edgeMedia["items"] as? [[String: Any]] {
                for item in items {
                    if let post = parseV1Item(item: item, username: username,
                                              displayName: displayName) {
                        posts.append(post)
                    }
                }
            }
        }

        if posts.isEmpty, let media = user["media"] as? [String: Any] {
            if let items = media["items"] as? [[String: Any]] {
                for item in items {
                    if let post = parseV1Item(item: item, username: username,
                                              displayName: displayName) {
                        posts.append(post)
                    }
                }
            }
        }

        log("InstagramProvider", "Parsed \(posts.count) posts from profile response")

        return InstagramProfileFetchResult(
            posts: posts,
            profileImageURL: profileImageURL,
            displayName: displayName
        )
    }

    // MARK: - GraphQL Edge Format

    private static func parseEdgeNode(
        node: [String: Any], username: String, displayName: String?
    ) -> ParsedInstagramPost? {
        let id = node["id"] as? String ?? ""
        guard !id.isEmpty else { return nil }

        let shortcode = node["shortcode"] as? String ?? ""

        var captionText = ""
        if let edgeCaption = node["edge_media_to_caption"] as? [String: Any],
           let captionEdges = edgeCaption["edges"] as? [[String: Any]],
           let firstCaption = captionEdges.first,
           let captionNode = firstCaption["node"] as? [String: Any],
           let text = captionNode["text"] as? String {
            captionText = text
        }

        var imageURL = node["display_url"] as? String
            ?? node["thumbnail_src"] as? String
        if imageURL == nil,
           let resources = node["thumbnail_resources"] as? [[String: Any]] {
            let sorted = resources.sorted {
                ($0["config_width"] as? Int ?? 0) > ($1["config_width"] as? Int ?? 0)
            }
            imageURL = sorted.first?["src"] as? String
        }

        var carouselImageURLs: [String] = []
        if let sidecar = node["edge_sidecar_to_children"] as? [String: Any],
           let edges = sidecar["edges"] as? [[String: Any]] {
            for edge in edges {
                guard let childNode = edge["node"] as? [String: Any] else { continue }
                if let childURL = childNode["display_url"] as? String {
                    carouselImageURLs.append(childURL)
                }
            }
        }

        var publishedDate: Date?
        if let timestamp = node["taken_at_timestamp"] as? TimeInterval {
            publishedDate = Date(timeIntervalSince1970: timestamp)
        }

        let isVideo = node["is_video"] as? Bool ?? false
        let pathSegment = isVideo ? "reel" : "p"
        let postURL = "https://www.instagram.com/\(pathSegment)/\(shortcode)/"
        let authorName = displayName ?? username

        return ParsedInstagramPost(
            id: id,
            text: captionText,
            author: authorName,
            authorHandle: username,
            url: postURL,
            imageURL: carouselImageURLs.first ?? imageURL,
            carouselImageURLs: carouselImageURLs,
            publishedDate: publishedDate
        )
    }

    // MARK: - v1 API Item Format

    // swiftlint:disable:next function_body_length
    private static func parseV1Item(
        item: [String: Any], username: String, displayName: String?
    ) -> ParsedInstagramPost? {
        let id: String
        if let idStr = item["id"] as? String {
            id = idStr
        } else if let pk = item["pk"] as? Int64 {
            // swiftlint:disable:previous identifier_name
            id = String(pk)
        } else if let pk = item["pk"] as? String {
            // swiftlint:disable:previous identifier_name
            id = pk
        } else {
            return nil
        }
        guard !id.isEmpty else { return nil }

        let code = item["code"] as? String ?? ""

        var captionText = ""
        if let caption = item["caption"] as? [String: Any],
           let text = caption["text"] as? String {
            captionText = text
        }

        var imageURL: String?
        var carouselImageURLs: [String] = []
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

        var publishedDate: Date?
        if let timestamp = item["taken_at"] as? TimeInterval {
            publishedDate = Date(timeIntervalSince1970: timestamp)
        }

        let isReel = (item["media_type"] as? Int) == 2
            || (item["product_type"] as? String) == "clips"
        let pathSegment = isReel ? "reel" : "p"
        let postURL = code.isEmpty
            ? "https://www.instagram.com/\(pathSegment)/\(id)/"
            : "https://www.instagram.com/\(pathSegment)/\(code)/"
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

    // MARK: - User ID Extraction

    static func extractUserID(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any] else {
            return nil
        }
        if let idStr = user["id"] as? String {
            return idStr
        } else if let pk = user["pk"] as? Int64 {
            // swiftlint:disable:previous identifier_name
            return String(pk)
        } else if let pk = user["pk"] as? String {
            // swiftlint:disable:previous identifier_name
            return pk
        }
        return nil
    }

    // MARK: - Feed Endpoint Parsing

    static func parseFeedResponse(
        data: Data, username: String, displayName: String?
    ) -> [ParsedInstagramPost] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            log("InstagramProvider", "Failed to parse feed JSON structure")
            return []
        }

        var posts: [ParsedInstagramPost] = []
        for item in items {
            if let post = parseV1Item(item: item, username: username,
                                       displayName: displayName) {
                posts.append(post)
            }
        }

        log("InstagramProvider", "Parsed \(posts.count) posts from feed response")

        return posts
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
