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
    /// A list made before list sync existed absorbed the remote members, so
    /// the merged list needs uploading.
    case merged
}
