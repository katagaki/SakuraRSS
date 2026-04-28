import Foundation

extension SubstackPublicationScraper {

    func performFetch(url: URL) async -> SubstackPublicationScrapeResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = SubstackPublicationScrapeResult(logoURL: nil)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else { return empty }

            let logoURL = (root["logo_url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (root["cover_photo_url"] as? String).flatMap { $0.isEmpty ? nil : $0 }

            return SubstackPublicationScrapeResult(logoURL: logoURL)
        } catch {
            print("[SubstackPublication] Fetch failed - \(error.localizedDescription)")
            return empty
        }
    }
}
