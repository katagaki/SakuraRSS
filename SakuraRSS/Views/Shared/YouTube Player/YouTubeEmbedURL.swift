import Foundation

/// Builds a YouTube embed-player URL from a regular watch URL.  Loading the
/// embed player avoids the surrounding mobile YouTube page (header, related
/// videos, comments, subscribe button, etc.) so the only thing rendered in the
/// web view is the actual video.
nonisolated enum YouTubeEmbedURL {

    static func embedURL(from urlString: String, autoplay: Bool) -> URL? {
        guard let videoID = SponsorBlockClient.extractVideoID(from: urlString) else {
            return nil
        }
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")
        components?.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "controls", value: "0"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "iv_load_policy", value: "3"),
            URLQueryItem(name: "disablekb", value: "1"),
            URLQueryItem(name: "fs", value: "0"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "autoplay", value: autoplay ? "1" : "0")
        ]
        return components?.url
    }
}
