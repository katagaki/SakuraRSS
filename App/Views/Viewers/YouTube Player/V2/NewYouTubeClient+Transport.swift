import Compression
import Foundation
import zlib

extension NewYouTubeClient {

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
        log("YouTube", "POST \(endpoint): web clientVersion: \(clientVersion), iosClientVersion: \(iosClientVersion), userAgent: \(iosUserAgent)")
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
            log("YouTube", "POST \(endpoint): HTTP \(http.statusCode)")
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
