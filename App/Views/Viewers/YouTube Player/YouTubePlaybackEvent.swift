import WebKit

/// Sendable representation of a single message from the YouTube WebView's
/// playback event bridge.
struct PlaybackEvent: Sendable {

    enum Kind: String, Sendable {
        case play
        case playing
        case pause
        case buffering
        case ended
        case seek
        case time
        case duration
        case rate
        case meta
        case ad
    }

    let kind: Kind
    let currentTime: Double?
    let duration: Double?
    let videoWidth: Double?
    let videoHeight: Double?
    let isAd: Bool?
    let adSkippable: Bool?
    let advertiserURL: String?

    init?(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let raw = dict["event"] as? String,
              let kind = Kind(rawValue: raw) else { return nil }
        self.kind = kind
        self.currentTime = dict["currentTime"] as? Double
        self.duration = dict["duration"] as? Double
        self.videoWidth = dict["videoWidth"] as? Double
        self.videoHeight = dict["videoHeight"] as? Double
        self.isAd = dict["isAd"] as? Bool
        self.adSkippable = dict["adSkippable"] as? Bool
        self.advertiserURL = dict["advertiserURL"] as? String
    }
}
