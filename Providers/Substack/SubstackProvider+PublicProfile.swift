import Foundation

extension SubstackProvider {

    /// Derives the user handle from a Substack publication host.
    /// `garymarcus.substack.com` -> `garymarcus`.
    nonisolated static func handle(from host: String) -> String? {
        let lower = host.lowercased()
        guard lower.hasSuffix(".substack.com"),
              let dot = lower.firstIndex(of: ".") else { return nil }
        let handle = String(lower[..<dot])
        return handle.isEmpty ? nil : handle
    }

    /// Fetches the publication's logo URL via the `public_profile` API.
    /// Prefers `primaryPublication.logo_url`, falling back to the user's
    /// own `photo_url` for personal publications without a logo.
    func fetchPublicProfileLogo(host: String) async -> SubstackPublicProfileLogo? {
        guard let handle = Self.handle(from: host),
              let url = URL(string: "https://\(host)/api/v1/user/\(handle)/public_profile") else {
            log("SubstackPublication", "public_profile: bad host/handle for \(host)")
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("SubstackPublication", "public_profile: \(host) handle=\(handle) HTTP \(status) bytes=\(data.count)")

            let profile = try JSONDecoder().decode(SubstackPublicProfile.self, from: data)

            if let logo = profile.primaryPublication?.logoURL, !logo.isEmpty,
               let url = URL(string: Self.upgradedImageURL(logo)) {
                log("SubstackPublication", "public_profile: using primaryPublication.logo_url for \(host)")
                return SubstackPublicProfileLogo(url: url, isAuthorPhoto: false)
            }

            if let photo = profile.photoURL, !photo.isEmpty,
               let url = URL(string: Self.squareCroppedPhotoURL(photo)) {
                log("SubstackPublication", "public_profile: using photo_url for \(host)")
                return SubstackPublicProfileLogo(url: url, isAuthorPhoto: true)
            }

            log("SubstackPublication", "public_profile: no logo or photo for \(host)")
            return nil
        } catch {
            print("[SubstackPublication] public_profile fetch failed - \(error.localizedDescription)")
            return nil
        }
    }
}
