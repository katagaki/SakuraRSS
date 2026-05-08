import Compression
import Foundation
import zlib

/// Transport layer for InnerTube API.
nonisolated struct YouTube: Sendable {

    static let host = "https://www.youtube.com"
    static let fallbackVersion = "2.20260505.01.00"
    static let fallbackIOSVersion = "21.18.4"
    static let youtubeAppID = "544007664"

    let session: URLSession
    let clientVersion: String
    let iosClientVersion: String

    var iosUserAgent: String {
        "com.google.ios.youtube/\(iosClientVersion) (iPhone; U; CPU iOS 18_7 like Mac OS X)"
    }

    static func bootstrap(session: URLSession = .shared) async -> YouTube {
        async let webVersion = fetchClientVersion(session: session)
        async let iosVersion = fetchIOSClientVersion(session: session)
        let resolvedWebVersion = (try? await webVersion) ?? fallbackVersion
        let resolvedIOSVersion = (try? await iosVersion) ?? fallbackIOSVersion
        log("YouTube", "Web client version: \(resolvedWebVersion)")
        log("YouTube", "iOS client version: \(resolvedIOSVersion)")
        log("YouTube", "hl: \(deviceLanguage), gl: \(deviceRegion)")
        return YouTube(
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

    func webContext() -> [String: Any] {
        [
            "client": [
                "clientName": "WEB",
                "clientVersion": clientVersion,
                "hl": Self.deviceLanguage,
                "gl": Self.deviceRegion,
                "platform": "DESKTOP"
            ]
        ]
    }

    func iosContext() -> [String: Any] {
        [
            "client": [
                "clientName": "IOS",
                "clientVersion": iosClientVersion,
                "deviceMake": "Apple",
                "deviceModel": "iPhone",
                "osName": "iPhone",
                "osVersion": "18_7.22H20",
                "hl": Self.deviceLanguage,
                "gl": Self.deviceRegion
            ]
        ]
    }

    func post(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(Self.host)/youtubei/v1/\(endpoint)?prettyPrint=false") else {
            throw YouTubeBrowseError.invalidURL
        }
        log("YouTube", "POST \(endpoint) — web clientVersion: \(clientVersion), iosClientVersion: \(iosClientVersion), userAgent: \(iosUserAgent)")
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        let payload = try Self.gzip(jsonData)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(Self.host, forHTTPHeaderField: "Origin")
        request.setValue("1", forHTTPHeaderField: "X-Youtube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-Youtube-Client-Version")

        let (data, response) = try await session.upload(for: request, from: payload)
        if let http = response as? HTTPURLResponse {
            log("YouTube", "POST \(endpoint) — HTTP \(http.statusCode)")
            if !(200..<300).contains(http.statusCode) {
                throw YouTubeBrowseError.unexpectedResponse(status: http.statusCode)
            }
        }
        return data
    }

    private static func gzip(_ data: Data) throws -> Data {
        let deflated = try rawDeflate(data)
        var output = Data(capacity: deflated.count + 18)
        output.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff])
        output.append(deflated)

        let crc = data.withUnsafeBytes { buffer -> UInt32 in
            guard let base = buffer.baseAddress else { return UInt32(crc32(0, nil, 0)) }
            return UInt32(crc32(0, base.assumingMemoryBound(to: Bytef.self), uInt(buffer.count)))
        }
        output.append(UInt8(crc & 0xff))
        output.append(UInt8((crc >> 8) & 0xff))
        output.append(UInt8((crc >> 16) & 0xff))
        output.append(UInt8((crc >> 24) & 0xff))

        let inputSize = UInt32(data.count & 0xffffffff)
        output.append(UInt8(inputSize & 0xff))
        output.append(UInt8((inputSize >> 8) & 0xff))
        output.append(UInt8((inputSize >> 16) & 0xff))
        output.append(UInt8((inputSize >> 24) & 0xff))
        return output
    }

    private static func rawDeflate(_ data: Data) throws -> Data {
        let destinationSize = max(data.count + 64, 256)
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destination.deallocate() }

        let written = data.withUnsafeBytes { buffer -> Int in
            guard let source = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_encode_buffer(
                destination, destinationSize, source, buffer.count, nil, COMPRESSION_ZLIB
            )
        }
        guard written > 0 else { throw YouTubeBrowseError.compressionFailed }
        return Data(bytes: destination, count: written)
    }
}
