import Foundation

extension InstagramProvider {
    static func parsePostsResponse(
        data: Data, username: String, bootstrap: InstagramProfileBootstrap
    ) -> InstagramProfileFetchResult? {
        guard var body = String(data: data, encoding: .utf8) else { return nil }
        if body.hasPrefix("for (;;);") { body.removeFirst(9) }
        guard let jsonData = body.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              payload["errors"] == nil,
              let responseData = payload["data"] as? [String: Any],
              let connection = responseData["xdt_api__v1__feed__user_timeline_graphql_connection"] as? [String: Any],
              let edges = connection["edges"] as? [[String: Any]] else { return nil }
        var posts: [ParsedInstagramPost] = []
        var displayName = bootstrap.displayName
        var profileImageURL = bootstrap.profileImageURL
        var seenIDs = Set<String>()
        for edge in edges {
            guard let node = edge["node"] as? [String: Any],
                  let user = node["user"] as? [String: Any],
                  let authorHandle = user["username"] as? String,
                  !authorHandle.isEmpty,
                  let post = parseV1Item(
                    item: node, username: authorHandle, displayName: user["full_name"] as? String
                  ) else { return nil }
            if authorHandle.caseInsensitiveCompare(username) == .orderedSame {
                displayName = user["full_name"] as? String ?? displayName
                profileImageURL = user["profile_pic_url"] as? String ?? profileImageURL
            }
            if seenIDs.insert(post.id).inserted { posts.append(post) }
        }
        return InstagramProfileFetchResult(
            posts: posts, profileImageURL: profileImageURL, displayName: displayName
        )
    }

}
