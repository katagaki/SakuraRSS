import Foundation

/// A page pushed by `navigationDestination(item:)` rather than onto the tab's
/// path. The stack shows it, but the path never changes, so it cannot report
/// itself the way a pushed page does: it is filed against the tab separately
/// and preferred for as long as its binding holds an item.
public struct OverlayPage<Identity: TabPageIdentity>: Identifiable {
    public let id: UUID
    public var identity: Identity
    public var dismiss: () -> Void

    public init(id: UUID, identity: Identity, dismiss: @escaping () -> Void) {
        self.id = id
        self.identity = identity
        self.dismiss = dismiss
    }
}
