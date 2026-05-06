import Foundation

/// Fetches Substack publication metadata via the public `/api/v1/publication` endpoint.
final class SubstackProvider {

    // MARK: - Static Helpers

    nonisolated static func isSubstackHost(_ host: String?) -> Bool {
        matchesHost(host)
    }

    nonisolated static func isSubstackPublicationHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(),
              host.hasSuffix(".substack.com"),
              host != "www.substack.com",
              host != "on.substack.com",
              host != "open.substack.com" else { return false }
        return true
    }

    nonisolated static func isSubstackPublicationURL(_ url: URL) -> Bool {
        isSubstackPublicationHost(url.host)
    }

    nonisolated static func isSubstackFeedURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              isSubstackPublicationHost(url.host) else { return false }
        return url.path.hasSuffix("/feed")
    }

    nonisolated static func publicationAPIURL(for host: String) -> URL? {
        URL(string: "https://\(host)/api/v1/publication")
    }

    /// If the URL is a Substack CDN fetch wrapper, returns the underlying full-resolution URL.
    nonisolated static func upgradedImageURL(_ urlString: String) -> String {
        guard urlString.lowercased().contains("substackcdn.com/image/fetch/") else { return urlString }
        let prefixes = ["https%3A%2F%2F", "https%3a%2f%2f", "http%3A%2F%2F", "http%3a%2f%2f"]
        for prefix in prefixes {
            if let range = urlString.range(of: prefix) {
                let encoded = String(urlString[range.lowerBound...])
                if let decoded = encoded.removingPercentEncoding {
                    return decoded
                }
            }
        }
        return urlString
    }

    /// If the URL is a Substack CDN fetch wrapper, injects a center-aligned
    /// square crop. Uses `c_lfill` so the source isn't upscaled: for sources
    /// larger than 512px the result is 512x512; smaller sources keep their
    /// largest centered square at native resolution. Returns the input
    /// unchanged for non-wrapped URLs.
    nonisolated static func squareCroppedPhotoURL(_ urlString: String) -> String {
        let marker = "/image/fetch/"
        guard urlString.lowercased().contains("substackcdn.com\(marker)"),
              let markerRange = urlString.range(of: marker),
              let nextSlash = urlString[markerRange.upperBound...].firstIndex(of: "/") else {
            return urlString
        }
        let transforms = String(urlString[markerRange.upperBound..<nextSlash])
        let crop = "w_512,h_512,c_lfill,g_center"
        guard !transforms.contains("c_lfill"), !transforms.contains("c_fill") else { return urlString }
        let newTransforms = transforms.isEmpty ? crop : "\(transforms),\(crop)"
        return urlString.replacingCharacters(
            in: markerRange.upperBound..<nextSlash, with: newTransforms
        )
    }

    // MARK: - Public

    func fetchPublication(host: String) async -> SubstackPublicationFetchResult {
        guard let url = Self.publicationAPIURL(for: host) else {
            return SubstackPublicationFetchResult(logoURL: nil)
        }
        return await performFetch(url: url)
    }
}
