import Foundation

public extension SubstackProvider {

    func performFetch(url: URL) async -> SubstackPublicationFetchResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = SubstackPublicationFetchResult(logoURL: nil)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(SubstackPublicationResponse.self, from: data)
            let logoURL = decoded.logoURL.flatMap { $0.isEmpty ? nil : $0 }
            return SubstackPublicationFetchResult(logoURL: logoURL)
        } catch {
            log("SubstackPublication", "Fetch failed - \(error.localizedDescription)")
            return empty
        }
    }
}
