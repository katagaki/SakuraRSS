import Foundation
import Hanami

/// Errors raised by the InnerTube-based YouTube browse client.
nonisolated enum YouTubeBrowseError: Error, Sendable {
    case invalidURL
    case compressionFailed
    case decodingFailed
    case missingData
    case unexpectedResponse(status: Int)
}

extension YouTubeBrowseError: CustomStringConvertible {
    var description: String {
        switch self {
        case .invalidURL:
            return "invalidURL (could not construct request URL)"
        case .compressionFailed:
            return "compressionFailed (could not gzip request body)"
        case .decodingFailed:
            return "decodingFailed (response was not valid JSON or UTF-8)"
        case .missingData:
            return "missingData (expected fields were absent from the response)"
        case .unexpectedResponse(let status):
            return "unexpectedResponse (HTTP status \(status))"
        }
    }
}
