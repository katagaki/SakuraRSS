import Compression
import Foundation
import zlib

/// Transport layer for YouTube's internal `youtubei/v1` (InnerTube) API.
nonisolated struct YouTubeInnerTube: Sendable {

    static let host = "https://www.youtube.com"
    static let fallbackVersion = "2.20260505.01.00"
    static let iosUserAgent =
        "com.google.ios.youtube/20.10.4 (iPhone; U; CPU iOS 18_7 like Mac OS X)"

    let session: URLSession
    let clientVersion: String

    static func bootstrap(session: URLSession = .shared) async -> YouTubeInnerTube {
        let version = (try? await fetchClientVersion(session: session)) ?? fallbackVersion
        return YouTubeInnerTube(session: session, clientVersion: version)
    }

    static func fetchClientVersion(session: URLSession) async throws -> String {
        guard let url = URL(string: "\(host)/sw.js") else {
            throw YouTubeBrowseError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        guard let body = String(data: data, encoding: .utf8) else {
            throw YouTubeBrowseError.decodingFailed
        }
        let pattern = #""INNERTUBE_CONTEXT_CLIENT_VERSION":"([^"]+)""#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
            match.numberOfRanges >= 2,
            let range = Range(match.range(at: 1), in: body)
        else { throw YouTubeBrowseError.decodingFailed }
        return String(body[range])
    }

    func webContext() -> [String: Any] {
        [
            "client": [
                "clientName": "WEB",
                "clientVersion": clientVersion,
                "hl": "en",
                "gl": "US",
                "platform": "DESKTOP"
            ]
        ]
    }

    func iosContext() -> [String: Any] {
        [
            "client": [
                "clientName": "IOS",
                "clientVersion": "21.18.4",
                "deviceMake": "Apple",
                "deviceModel": "iPhone",
                "osName": "iPhone",
                "osVersion": "18_7.22H20",
                "hl": "en",
                "gl": "US"
            ]
        ]
    }

    func post(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(Self.host)/youtubei/v1/\(endpoint)?prettyPrint=false") else {
            throw YouTubeBrowseError.invalidURL
        }
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
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YouTubeBrowseError.unexpectedResponse(status: http.statusCode)
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
