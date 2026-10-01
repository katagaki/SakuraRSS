import Foundation

public nonisolated enum SakuraCloudError: Error, Equatable {
    case notConfigured
    case unsupported
    case limitReached(retryAfter: TimeInterval?)
    case server(Int, String?)
    case noResponse
}
