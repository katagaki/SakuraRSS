import Foundation

// MARK: - Response Parsing

extension InstagramProfileScraper {

    static func parseProfileResponse(
        data: Data, username: String
    ) -> InstagramProfileScrapeResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any] else {
            #if DEBUG
            print("[InstagramProfileScraper] Failed to parse profile JSON structure")
            #endif
            return nil
        }

        let displayName = user["full_name"] as? String
        let profileImageURL = user["profile_pic_url_hd"] as? String
            ?? user["profile_pic_url"] as? String

        // Parse timeline media
        guard let edgeMedia = user["edge_owner_to_timeline_media"] as? [String: Any],
              let edges = edgeMedia["edges"] as? [[String: Any]] else {
            #if DEBUG
            print("[InstagramProfileScraper] No timeline media found")
            #endif
            return InstagramProfileScrapeResult(
                posts: [],
                profileImageURL: profileImageURL,
                displayName: displayName
            )
        }

        var posts: [ParsedInstagramPost] = []

        for edge in edges {
            guard let node = edge["node"] as? [String: Any] else { continue }
            if let post = parsePostNode(node: node, username: username,
                                        displayName: displayName) {
                posts.append(post)
            }
        }

        #if DEBUG
        print("[InstagramProfileScraper] Parsed \(posts.count) posts from profile response")
        #endif

        return InstagramProfileScrapeResult(
            posts: posts,
            profileImageURL: profileImageURL,
            displayName: displayName
        )
    }

    private static func parsePostNode(
        node: [String: Any], username: String, displayName: String?
    ) -> ParsedInstagramPost? {
        let id = node["id"] as? String ?? ""
        guard !id.isEmpty else { return nil }

        let shortcode = node["shortcode"] as? String ?? ""

        // Caption text
        var captionText = ""
        if let edgeCaption = node["edge_media_to_caption"] as? [String: Any],
           let captionEdges = edgeCaption["edges"] as? [[String: Any]],
           let firstCaption = captionEdges.first,
           let captionNode = firstCaption["node"] as? [String: Any],
           let text = captionNode["text"] as? String {
            captionText = text
        }

        // Image URL
        let imageURL = node["display_url"] as? String
            ?? node["thumbnail_src"] as? String

        // Publish date
        var publishedDate: Date?
        if let timestamp = node["taken_at_timestamp"] as? TimeInterval {
            publishedDate = Date(timeIntervalSince1970: timestamp)
        }

        let postURL = "https://www.instagram.com/p/\(shortcode)/"
        let authorName = displayName ?? username

        return ParsedInstagramPost(
            id: id,
            text: captionText,
            author: authorName,
            authorHandle: username,
            url: postURL,
            imageURL: imageURL,
            publishedDate: publishedDate
        )
    }
}
