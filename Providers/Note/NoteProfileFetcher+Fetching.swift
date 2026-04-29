import Foundation

extension NoteProfileFetcher {

    func performFetch(url: URL) async -> NoteProfileFetchResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let empty = NoteProfileFetchResult(profileImageURL: nil, displayName: nil)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else { return empty }

            let payload = (root["data"] as? [String: Any]) ?? root

            let imageURL = payload["profileImageUrl"] as? String
            let displayName = payload["nickname"] as? String

            let cleanedImage = imageURL.flatMap { $0.isEmpty ? nil : $0 }
            let cleanedName = displayName.flatMap { $0.isEmpty ? nil : $0 }

            return NoteProfileFetchResult(
                profileImageURL: cleanedImage,
                displayName: cleanedName
            )
        } catch {
            print("[NoteProfile] Fetch failed - \(error.localizedDescription)")
            return empty
        }
    }
}
