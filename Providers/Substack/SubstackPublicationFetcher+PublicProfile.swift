import Foundation

private struct SubstackPublicProfile: Decodable {
    let photoURL: String?
    let primaryPublication: PrimaryPublication?

    struct PrimaryPublication: Decodable {
        let logoURL: String?

        enum CodingKeys: String, CodingKey {
            case logoURL = "logo_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
        case primaryPublication
    }
}

struct SubstackPublicProfileLogo: Sendable {
    let url: URL
    /// True when the URL is the user's own `photo_url` (an arbitrary-aspect
    /// portrait) rather than a publication logo. Callers should center-crop.
    let isAuthorPhoto: Bool
}

extension SubstackPublicationFetcher {

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
            #if DEBUG
            debugPrint("[SubstackPublication] public_profile: bad host/handle for \(host)")
            #endif
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            #if DEBUG
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            debugPrint("[SubstackPublication] public_profile: \(host) handle=\(handle) HTTP \(status) bytes=\(data.count)")
            #endif

            let profile = try JSONDecoder().decode(SubstackPublicProfile.self, from: data)

            if let logo = profile.primaryPublication?.logoURL, !logo.isEmpty,
               let url = URL(string: Self.upgradedImageURL(logo)) {
                #if DEBUG
                debugPrint("[SubstackPublication] public_profile: using primaryPublication.logo_url for \(host)")
                #endif
                return SubstackPublicProfileLogo(url: url, isAuthorPhoto: false)
            }

            if let photo = profile.photoURL, !photo.isEmpty,
               let url = URL(string: Self.squareCroppedPhotoURL(photo)) {
                #if DEBUG
                debugPrint("[SubstackPublication] public_profile: using photo_url for \(host)")
                #endif
                return SubstackPublicProfileLogo(url: url, isAuthorPhoto: true)
            }

            #if DEBUG
            debugPrint("[SubstackPublication] public_profile: no logo or photo for \(host)")
            #endif
            return nil
        } catch {
            print("[SubstackPublication] public_profile fetch failed - \(error.localizedDescription)")
            return nil
        }
    }
}
