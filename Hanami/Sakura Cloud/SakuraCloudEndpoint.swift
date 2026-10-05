import Foundation

nonisolated enum SakuraCloudEndpoint: String {
    case attest
    case challenge
    case classify

    static let version = "v1"
}
