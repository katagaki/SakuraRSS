import Foundation

extension PixelfedProvider: MetadataProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let host = url.host?.lowercased(),
              let username = extractIdentifier(from: url) else {
            log("PixelfedProvider", "fetchMetadata skip url=\(url.absoluteString) reason=unrecognized")
            return nil
        }
        log("PixelfedProvider", "fetchMetadata begin host=\(host) username=\(username)")
        let result = await PixelfedProvider().fetchProfile(host: host, username: username)
        let iconURL = result.profileImageURL.flatMap(URL.init(string:))
        // swiftlint:disable:next line_length
        log("PixelfedProvider", "fetchMetadata end host=\(host) username=\(username) iconURL=\(iconURL?.absoluteString ?? "nil")")
        return FetchedFeedMetadata(
            displayName: nil,
            iconURL: iconURL,
            iconNeedsSquareCrop: true
        )
    }
}
