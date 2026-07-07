import Foundation

public extension RedditProvider {

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
            log("RedditCommunity", "Fetch failed - \(error.localizedDescription)")
            return empty
        }
    }

    /// Reddit serves `about.json` behind bot verification on some networks,
    /// but the Atom feed stays reachable and carries the community icon in
    /// its feed-level `<logo>` element.
    func performCommunityFeedLogoFetch(subreddit: String) async -> RedditCommunityFetchResult {
        let empty = RedditCommunityFetchResult(communityIconURL: nil)
        guard let url = Self.atomFeedURL(for: subreddit) else { return empty }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let feedXML = String(data: data, encoding: .utf8),
                  let logoURL = Self.extractAtomLogoURL(from: feedXML) else {
                return empty
            }
            return RedditCommunityFetchResult(
                communityIconURL: Self.stripQuery(from: logoURL)
            )
        } catch {
            log("RedditCommunity", "Feed logo fetch failed - \(error.localizedDescription)")
            return empty
        }
    }

    nonisolated static func extractAtomLogoURL(from feedXML: String) -> String? {
        guard let openRange = feedXML.range(of: "<logo>"),
              let closeRange = feedXML.range(
                of: "</logo>",
                range: openRange.upperBound..<feedXML.endIndex
              ) else { return nil }
        let logoURL = unescapeAmpersand(String(feedXML[openRange.upperBound..<closeRange.lowerBound]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return logoURL.isEmpty ? nil : logoURL
    }
}
