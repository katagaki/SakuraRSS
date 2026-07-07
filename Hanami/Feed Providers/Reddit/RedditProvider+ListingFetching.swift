import Foundation

public extension RedditProvider {

    func performListingFetch(url: URL) async -> RedditListingFetchResult {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = RedditListingFetchResult(imagesByPostID: [:])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                log("RedditListing", "Listing fetch blocked or failed - HTTP \(http.statusCode)")
                return empty
            }
            let json = try JSONSerialization.jsonObject(with: data)
            return Self.extractListingResult(from: json)
        } catch {
            log("RedditListing", "Listing fetch failed - \(error.localizedDescription)")
            return empty
        }
    }
}
