import Foundation

/// Sign-in transitions for cookie-authenticated providers. Profile icons for
/// these services are only reachable with a session, so callers listen here to
/// refetch icons that failed while signed out.
@MainActor
public enum ProviderSessionEvents {

    public enum Service: String, Sendable {
        // swiftlint:disable:next identifier_name
        case x
        case instagram
        case substack

        public func matches(_ feed: Feed) -> Bool {
            switch self {
            case .x: return feed.isXFeed
            case .instagram: return feed.isInstagramFeed
            case .substack: return feed.isSubstackFeed
            }
        }
    }

    public static var onSessionEstablished: ((Service) -> Void)?

    static func sessionEstablished(_ service: Service) {
        onSessionEstablished?(service)
    }
}
