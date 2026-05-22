import AVFoundation
import Foundation
import UniformTypeIdentifiers
import Hanami

/// Serves a synthesized `YouTubeLocalHLSStream` to `AVPlayer` over a custom URL
/// scheme. Text playlists are vended directly; media byte ranges are proxied
/// from googlevideo with the iOS User-Agent, because AVPlayer's own requests
/// are rejected for far-range seeks.
nonisolated final class LocalHLSResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {

    static let scheme = "sakurahls"
    // swiftlint:disable:next force_unwrapping
    static let masterURL = URL(string: "\(scheme)://stream/master.m3u8")!

    let queue = DispatchQueue(label: "com.sakurarss.localhls")
    private let playlists: [String: Data]
    private let mediaSources: [String: YouTubeLocalMediaSource]
    private let userAgent: String
    private let session: URLSession

    init(stream: YouTubeLocalHLSStream, session: URLSession = .shared) {
        playlists = stream.resources
        mediaSources = stream.mediaSources
        userAgent = stream.userAgent
        self.session = session
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

        let name = url.lastPathComponent
        if let data = playlists[name] {
            servePlaylist(data, url: url, loadingRequest: loadingRequest)
            return true
        }
        if let source = mediaSources[name] {
            proxyMedia(source, loadingRequest: loadingRequest)
            return true
        }
        log("YT Playback", "Loader MISS \(name)")
        loadingRequest.finishLoading(with: YouTubeBrowseError.missingData)
        return true
    }

    private func servePlaylist(
        _ data: Data,
        url: URL,
        loadingRequest: AVAssetResourceLoadingRequest
    ) {
        if let infoRequest = loadingRequest.contentInformationRequest {
            infoRequest.contentType = Self.playlistContentType(for: url)
            infoRequest.contentLength = Int64(data.count)
            infoRequest.isByteRangeAccessSupported = true
        }
        if let dataRequest = loadingRequest.dataRequest {
            let offset = Int(dataRequest.requestedOffset)
            if offset >= 0, offset < data.count {
                let length = min(dataRequest.requestedLength, data.count - offset)
                if length > 0 {
                    dataRequest.respond(with: data.subdata(in: offset..<(offset + length)))
                }
            }
        }
        loadingRequest.finishLoading()
    }

    private func proxyMedia(
        _ source: YouTubeLocalMediaSource,
        loadingRequest: AVAssetResourceLoadingRequest
    ) {
        if let infoRequest = loadingRequest.contentInformationRequest {
            let fallback = source.mimeType.hasPrefix("audio")
                ? UTType.mpeg4Audio : UTType.mpeg4Movie
            infoRequest.contentType = UTType(mimeType: source.mimeType)?.identifier
                ?? fallback.identifier
            infoRequest.contentLength = Int64(source.contentLength)
            infoRequest.isByteRangeAccessSupported = true
        }
        guard
            let dataRequest = loadingRequest.dataRequest,
            let url = URL(string: source.url)
        else {
            loadingRequest.finishLoading()
            return
        }
        let offset = Int(dataRequest.requestedOffset)
        let length = dataRequest.requestsAllDataToEndOfResource
            ? max(0, source.contentLength - offset)
            : dataRequest.requestedLength
        guard length > 0 else {
            loadingRequest.finishLoading()
            return
        }
        var request = URLRequest(url: url)
        request.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        log("YT Playback", "Proxy \(url.lastPathComponent) bytes=\(offset)-\(offset + length - 1)")

        nonisolated(unsafe) let request_ = loadingRequest
        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                log("YT Playback", "Proxy error: \(error.localizedDescription)")
                request_.finishLoading(with: error)
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                log("YT Playback", "Proxy HTTP \(http.statusCode)")
                request_.finishLoading(with: YouTubeBrowseError.unexpectedResponse(status: http.statusCode))
                return
            }
            if let data { request_.dataRequest?.respond(with: data) }
            request_.finishLoading()
        }
        task.resume()
    }

    private static func playlistContentType(for url: URL) -> String {
        if url.pathExtension.lowercased() == "vtt" {
            return UTType(filenameExtension: "vtt")?.identifier ?? "public.text"
        }
        return UTType.m3uPlaylist.identifier
    }
}
