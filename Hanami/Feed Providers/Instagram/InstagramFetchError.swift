import Foundation

public enum InstagramFetchError: Error, Sendable {
    case missingSession
    case invalidResponse
    case httpStatus(Int)
    case rateLimited(until: Date)
}
