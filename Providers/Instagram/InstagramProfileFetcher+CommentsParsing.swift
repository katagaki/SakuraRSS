import Foundation

// MARK: - Comments HTML/JSON Parsing

extension InstagramProfileFetcher {

    /// Locates the `<script type="application/json">` block whose body
    /// contains the rendered comments connection, then walks the JSON to
    /// the `xdt_api__v1__media__media_id__comments__connection.edges` array.
    static func parseCommentsHTML(_ html: String, shortcode: String) -> [ParsedInstagramComment] {
        let key = "xdt_api__v1__media__media_id__comments__connection"
        guard let payload = applicationJSONScript(containing: key, in: html) else {
            log("InstagramProfileFetcher", "Comments JSON script not found in HTML")
            return []
        }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log("InstagramProfileFetcher", "Comments JSON failed to deserialize")
            return []
        }

        guard let edges = findCommentEdges(in: json) else {
            log("InstagramProfileFetcher", "Comments edges not found in JSON tree")
            return []
        }

        return edges.compactMap { edge in
            guard let node = edge["node"] as? [String: Any] else { return nil }
            return parseCommentNode(node, shortcode: shortcode)
        }
    }

    // MARK: - Script Extraction

    /// Returns the body of the first `<script type="application/json" …>…</script>`
    /// whose body contains `key`. The HTML wraps each candidate in extra
    /// `data-content-len` / `data-sjs` attributes that vary, so we scan with
    /// a regex rather than a strict tag match.
    private static func applicationJSONScript(containing key: String, in html: String) -> String? {
        let pattern = #"<script[^>]*type=\"application/json\"[^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsHTML = html as NSString
        let matches = regex.matches(
            in: html, range: NSRange(location: 0, length: nsHTML.length)
        )
        for match in matches where match.numberOfRanges >= 2 {
            let body = nsHTML.substring(with: match.range(at: 1))
            if body.contains(key) { return body }
        }
        return nil
    }

    // MARK: - JSON Tree Walking

    /// Depth-first search for the comments `edges` array. Instagram nests the
    /// connection under several wrappers (`require → __bbox → … → data →
    /// xdt_api__v1__media__media_id__comments__connection`) that aren't
    /// stable across rollouts, so a recursive walk is more robust than a
    /// hard-coded path.
    private static func findCommentEdges(in object: Any) -> [[String: Any]]? {
        if let dict = object as? [String: Any] {
            if let connection = dict["xdt_api__v1__media__media_id__comments__connection"]
                as? [String: Any],
               let edges = connection["edges"] as? [[String: Any]] {
                return edges
            }
            for value in dict.values {
                if let found = findCommentEdges(in: value) { return found }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let found = findCommentEdges(in: value) { return found }
            }
        }
        return nil
    }

    // MARK: - Comment Node Parsing

    private static func parseCommentNode(
        _ node: [String: Any], shortcode: String
    ) -> ParsedInstagramComment? {
        let id: String
        if let pkStr = node["pk"] as? String {
            id = pkStr
        } else if let pkInt = node["pk"] as? Int64 {
            id = String(pkInt)
        } else if let pkInt = node["pk"] as? Int {
            id = String(pkInt)
        } else {
            return nil
        }
        guard !id.isEmpty else { return nil }

        let text = (node["text"] as? String) ?? ""
        let likeCount = (node["comment_like_count"] as? Int) ?? 0

        var publishedDate: Date?
        if let timestamp = node["created_at"] as? TimeInterval {
            publishedDate = Date(timeIntervalSince1970: timestamp)
        } else if let timestampInt = node["created_at"] as? Int {
            publishedDate = Date(timeIntervalSince1970: TimeInterval(timestampInt))
        }

        let user = node["user"] as? [String: Any]
        let username = (user?["username"] as? String) ?? ""
        let fullName = (user?["full_name"] as? String) ?? ""

        let sourceURL = "https://www.instagram.com/p/\(shortcode)/c/\(id)/"

        return ParsedInstagramComment(
            id: id,
            text: text,
            author: fullName,
            authorHandle: username,
            likeCount: likeCount,
            publishedDate: publishedDate,
            sourceURL: sourceURL
        )
    }
}
