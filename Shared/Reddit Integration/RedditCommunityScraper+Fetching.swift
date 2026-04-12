import Foundation

extension RedditCommunityScraper {

    /// Fetches `about.json` for the subreddit and extracts `community_icon`.
    /// The query string is stripped from the returned URL because Reddit's
    /// signed params are not required for the image to load.
    func performFetch(url: URL) async -> RedditCommunityScrapeResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = RedditCommunityScrapeResult(communityIconURL: nil)

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
            return RedditCommunityScrapeResult(
                communityIconURL: Self.stripQuery(from: rawIcon)
            )
        } catch {
            print("[RedditCommunity] Fetch failed — \(error.localizedDescription)")
            return empty
        }
    }
}
