import AVFoundation
import Foundation
import UniformTypeIdentifiers
import Hanami

/// Serves a synthesized `YouTubeLocalHLSStream` to `AVPlayer` over a custom URL
/// scheme. Only the small text playlists are vended here; the media segments
/// they reference use absolute https URLs that `AVPlayer` fetches directly.
nonisolated final class LocalHLSResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {

    static let scheme = "sakurahls"
    // swiftlint:disable:next force_unwrapping
    static let masterURL = URL(string: "\(scheme)://stream/master.m3u8")!

    let queue = DispatchQueue(label: "com.sakurarss.localhls")
    private let playlists: [String: Data]

    init(stream: YouTubeLocalHLSStream) {
        playlists = [
            "master.m3u8": Data(stream.masterPlaylist.utf8),
            "video.m3u8": Data(stream.videoPlaylist.utf8),
            "audio.m3u8": Data(stream.audioPlaylist.utf8)
        ]
        super.init()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard
            let url = loadingRequest.request.url,
            url.scheme == Self.scheme
        else { return false }

        guard let data = playlists[url.lastPathComponent] else {
            loadingRequest.finishLoading(with: YouTubeBrowseError.missingData)
            return true
        }

        if let infoRequest = loadingRequest.contentInformationRequest {
            infoRequest.contentType = UTType.m3uPlaylist.identifier
            infoRequest.contentLength = Int64(data.count)
            infoRequest.isByteRangeAccessSupported = true
        }

        if let dataRequest = loadingRequest.dataRequest {
            let offset = Int(dataRequest.requestedOffset)
            guard offset >= 0, offset <= data.count else {
                loadingRequest.finishLoading()
                return true
            }
            let remaining = data.count - offset
            let length = min(dataRequest.requestedLength, remaining)
            if length > 0 {
                dataRequest.respond(with: data.subdata(in: offset..<(offset + length)))
            }
        }

        loadingRequest.finishLoading()
        return true
    }
}
