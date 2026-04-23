import Foundation

extension RedditListingScraper {

    func performFetch(url: URL) async -> RedditListingScrapeResult {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = RedditListingScrapeResult(imagesByPostID: [:])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                return empty
            }
            let json = try JSONSerialization.jsonObject(with: data)
            return Self.extractResult(from: json)
        } catch {
            return empty
        }
    }
}
