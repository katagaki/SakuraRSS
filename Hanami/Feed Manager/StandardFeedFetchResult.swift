import CryptoKit
import Foundation

nonisolated enum StandardFeedFetchResult {
    case failed
    case unchanged
    case parsed(ParsedFeed, validators: FeedHTTPValidators)
}

nonisolated extension FeedHTTPValidators {

    /// Salted with the build number so a parser change in an app update
    /// re-parses feeds whose bytes haven't changed since the last fetch.
    static func bodyHash(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(build):\(hex)"
    }

    func applyConditionalHeaders(to request: inout URLRequest) {
        guard eTag != nil || lastModified != nil else { return }
        // URLCache would otherwise turn a 304 into a 200 carrying the cached body.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let eTag {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
    }
}
