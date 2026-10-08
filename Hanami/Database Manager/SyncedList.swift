import Foundation

nonisolated struct SyncedList: Sendable {
    var syncID: String
    var name: String
    var icon: String
    var displayStyle: String?
    var sortOrder: Int
    var memberFeedSyncIDs: [String]
    var rules: [String: [String]]
    var userModifiedAt: Date?
}

nonisolated enum SyncedListApplyOutcome: Sendable {
    case skipped
    case applied
    /// A local list with the same name absorbed the remote one. The surviving
    /// record needs uploading, and the superseded one (if any) deleting.
    case merged(survivingSyncID: String, supersededSyncID: String?)
}
