import Foundation

public extension XProvider {

    /// Fetches the raw TweetDetail GraphQL response so callers can run
    /// their own parsing (e.g. extracting replies vs. the focal tweet).
    /// On a stale-query-ID failure (missing ID, non-200 response, or
    /// missing instructions), re-extracts query IDs from the current x.com
    /// bundle once and retries.  This is the same recovery path as the in-app
    /// "Refresh Authentication" button.
    func fetchTweetDetailData(tweetID: String) async -> Data? {
        if let data = await performTweetDetailFetch(tweetID: tweetID),
           Self.tweetDetailHasInstructions(data) {
            return data
        }
        log("XProvider", "TweetDetail failed; refreshing query IDs and retrying tweet=\(tweetID)")
        await MainActor.run { Self.queryIDsFetched = false }
        await Self.fetchQueryIDsIfNeeded()
        return await performTweetDetailFetch(tweetID: tweetID)
    }

    /// Returns true if the response actually contains the threaded
    /// conversation. A 200 with `errors` (e.g. "Operation not found" when
    /// the query ID has rotated) lacks this object.
    static func tweetDetailHasInstructions(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let threaded = dataObj["threaded_conversation_with_injections_v2"]
                  as? [String: Any],
              threaded["instructions"] is [[String: Any]] else {
            return false
        }
        return true
    }
}
