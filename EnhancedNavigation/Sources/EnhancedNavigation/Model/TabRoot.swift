import Foundation

/// What a tab is parked on beneath its pushed pages. Stored by token rather
/// than by value, so a tab survives whatever it names being edited.
public protocol TabRoot: Hashable {
    /// What a freshly opened tab shows.
    static var newTabRoot: Self { get }

    var persistenceToken: String { get }

    init?(persistenceToken: String)

    /// Whether opening this root counts towards the frequently visited list.
    var isRecordedAsVisit: Bool { get }
}

public extension TabRoot {
    var isRecordedAsVisit: Bool { false }
}
