import Foundation

extension NoteProfileScraper {

    /// Calls the v2 creators API and extracts the profile photo URL and
    /// display name. Returns an empty result on any failure; the favicon
    /// lookup path treats this as a miss and falls back to the generic
    /// favicon fetch.
    func performFetch(url: URL) async -> NoteProfileScrapeResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = NoteProfileScrapeResult(profileImageURL: nil, displayName: nil)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else { return empty }

            let payload = (root["data"] as? [String: Any]) ?? root

            let imageURL = payload["profileImageUrl"] as? String
            let displayName = payload["nickname"] as? String

            let cleanedImage = imageURL.flatMap { $0.isEmpty ? nil : $0 }
            let cleanedName = displayName.flatMap { $0.isEmpty ? nil : $0 }

            return NoteProfileScrapeResult(
                profileImageURL: cleanedImage,
                displayName: cleanedName
            )
        } catch {
            print("[NoteProfile] Fetch failed - \(error.localizedDescription)")
            return empty
        }
    }
}
