import Foundation

/// A page behind the current one, with the depth to pop back to.
public struct BackHistoryEntry<Identity: TabPageIdentity> {
    public let depth: Int
    public let identity: Identity
}
