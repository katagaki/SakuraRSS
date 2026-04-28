import Foundation

extension RedditPostFetcher {

    func performFetch(postID: String) async throws -> RedditPostFetchResult {
        guard let url = Self.jsonURL(for: postID) else {
            throw RedditPostFetcherError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await sendWithRetry(request: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RedditPostFetcherError.badResponse
        }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let listings = json as? [Any] else {
            throw RedditPostFetcherError.parseFailed
        }

        return try Self.extractResult(fromListings: listings)
    }

    private func sendWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return try await URLSession.shared.data(for: request)
        }
        return (data, response)
    }
}
