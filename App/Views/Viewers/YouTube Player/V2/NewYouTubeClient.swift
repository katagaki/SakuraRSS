import Foundation

/// Client for the InnerTube YouTube API. Resolves channel videos and stream
/// URLs without downloading media.
nonisolated struct NewYouTubeClient: Sendable {

    static let host = "https://www.youtube.com"
    static let youtubeAppID = "544007664"

    let session: URLSession
    let clientVersion: String
    let iosClientVersion: String

    var iosUserAgent: String {
        "com.google.ios.youtube/\(iosClientVersion) (iPhone; U; CPU iOS 18_7 like Mac OS X)"
    }

    static func bootstrap(session: URLSession = .shared) async throws -> NewYouTubeClient {
        async let webVersion = fetchClientVersion(session: session)
        async let iosVersion = fetchIOSClientVersion(session: session)
        let resolvedWebVersion = try await webVersion
        let resolvedIOSVersion = try await iosVersion
        log("YouTube", "Web client version: \(resolvedWebVersion)")
        log("YouTube", "iOS client version: \(resolvedIOSVersion)")
        log("YouTube", "hl: \(deviceLanguage), gl: \(deviceRegion)")
        return NewYouTubeClient(
            session: session,
            clientVersion: resolvedWebVersion,
            iosClientVersion: resolvedIOSVersion
        )
    }

    static func fetchIOSClientVersion(session: URLSession) async throws -> String {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(youtubeAppID)") else {
            throw YouTubeBrowseError.invalidURL
        }
        log("YouTube", "Fetching iOS client version from iTunes: \(url)")
        let (data, _) = try await session.data(from: url)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]],
            let version = results.first?["version"] as? String
        else {
            log("YouTube", "Failed to parse iOS client version from iTunes response")
            throw YouTubeBrowseError.decodingFailed
        }
        log("YouTube", "iTunes returned iOS client version: \(version)")
        return version
    }

    static func fetchClientVersion(session: URLSession) async throws -> String {
        guard let url = URL(string: "\(host)/sw.js") else {
            throw YouTubeBrowseError.invalidURL
        }
        log("YouTube", "Fetching web client version from: \(url)")
        let (data, _) = try await session.data(from: url)
        guard let body = String(data: data, encoding: .utf8) else {
            log("YouTube", "Failed to decode sw.js response")
            throw YouTubeBrowseError.decodingFailed
        }
        let pattern = #""INNERTUBE_CONTEXT_CLIENT_VERSION":"([^"]+)""#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
            match.numberOfRanges >= 2,
            let range = Range(match.range(at: 1), in: body)
        else {
            log("YouTube", "Failed to extract web client version from sw.js")
            throw YouTubeBrowseError.decodingFailed
        }
        let version = String(body[range])
        log("YouTube", "Extracted web client version: \(version)")
        return version
    }

    static var deviceLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    static var deviceRegion: String {
        Locale.current.region?.identifier ?? "US"
    }
}
