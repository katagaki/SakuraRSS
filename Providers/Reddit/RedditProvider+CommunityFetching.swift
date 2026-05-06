import Foundation

extension RedditProvider {

    func performCommunityFetch(url: URL) async -> RedditCommunityFetchResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = RedditCommunityFetchResult(communityIconURL: nil)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = root["data"] as? [String: Any] else {
                return empty
            }

            let rawIcon = (payload["community_icon"] as? String).flatMap {
                $0.isEmpty ? nil : $0
            } ?? (payload["icon_img"] as? String).flatMap {
                $0.isEmpty ? nil : $0
            }

            guard let rawIcon else { return empty }
            return RedditCommunityFetchResult(
                communityIconURL: Self.stripQuery(from: rawIcon)
            )
        } catch {
            print("[RedditCommunity] Fetch failed - \(error.localizedDescription)")
            return empty
        }
    }
}
