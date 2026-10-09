import CryptoKit
import Foundation
@preconcurrency import SQLite

public nonisolated struct PagePreference: Sendable, Equatable {
    public let pageKey: String
    public var hidesReadContent: Bool
    public var userModifiedAt: Date
}

public nonisolated extension DatabaseManager {

    static let pagePreferenceSyncIDPrefix = "pagepref."

    static func pagePreferenceSyncID(forPageKey pageKey: String) -> String {
        let digest = SHA256.hash(data: Data(pageKey.utf8))
        return pagePreferenceSyncIDPrefix + digest.map { String(format: "%02x", $0) }.joined()
    }

    var pagePreferences: Table { Table("page_preferences") }
    var pagePreferenceKey: SQLite.Expression<String> { SQLite.Expression<String>("page_key") }
    var pagePreferenceSyncID: SQLite.Expression<String> { SQLite.Expression<String>("sync_id") }
    var pagePreferenceHidesReadContent: SQLite.Expression<Bool> {
        SQLite.Expression<Bool>("hides_read_content")
    }
    var pagePreferenceUserModifiedAt: SQLite.Expression<Double> {
        SQLite.Expression<Double>("user_modified_at")
    }
    var pagePreferenceNeedsSync: SQLite.Expression<Bool> { SQLite.Expression<Bool>("needs_sync") }

    func createPagePreferencesTable() throws {
        try database.run(pagePreferences.create(ifNotExists: true) { table in
            table.column(pagePreferenceKey, primaryKey: true)
            table.column(pagePreferenceSyncID, unique: true)
            table.column(pagePreferenceHidesReadContent, defaultValue: false)
            table.column(pagePreferenceUserModifiedAt, defaultValue: 0)
            table.column(pagePreferenceNeedsSync, defaultValue: false)
        })
    }

    func allPagePreferences() throws -> [PagePreference] {
        try database.prepare(pagePreferences).map(rowToPagePreference)
    }

    func pagePreference(bySyncID syncID: String) throws -> PagePreference? {
        try database.pluck(pagePreferences.filter(pagePreferenceSyncID == syncID)).map(rowToPagePreference)
    }

    /// Saves a change made on this device and marks it for upload.
    func saveUserPagePreference(pageKey: String, hidesReadContent: Bool) throws {
        try upsertPagePreference(
            PagePreference(pageKey: pageKey, hidesReadContent: hidesReadContent, userModifiedAt: Date()),
            needsSync: true
        )
    }

    /// Applies a preference from another device unless this device's copy is newer.
    /// Returns whether the local row changed.
    @discardableResult
    func applySyncedPagePreference(_ synced: PagePreference) throws -> Bool {
        let syncID = Self.pagePreferenceSyncID(forPageKey: synced.pageKey)
        if let local = try pagePreference(bySyncID: syncID), local.userModifiedAt >= synced.userModifiedAt {
            return false
        }
        try upsertPagePreference(synced, needsSync: false)
        return true
    }

    func pagePreferenceSyncIDsNeedingSync() throws -> [String] {
        try database.prepare(
            pagePreferences.filter(pagePreferenceNeedsSync == true).select(pagePreferenceSyncID)
        ).map { $0[pagePreferenceSyncID] }
    }

    func allPagePreferenceSyncIDs() throws -> [String] {
        try database.prepare(pagePreferences.select(pagePreferenceSyncID)).map { $0[pagePreferenceSyncID] }
    }

    func clearPagePreferencesNeedSync(syncIDs: [String]) throws {
        guard !syncIDs.isEmpty else { return }
        try database.run(
            pagePreferences.filter(syncIDs.contains(pagePreferenceSyncID)).update(pagePreferenceNeedsSync <- false)
        )
    }

    func deletePagePreference(syncID: String) throws {
        try database.run(pagePreferences.filter(pagePreferenceSyncID == syncID).delete())
    }

    private func upsertPagePreference(_ preference: PagePreference, needsSync: Bool) throws {
        try database.run(pagePreferences.insert(
            or: .replace,
            pagePreferenceKey <- preference.pageKey,
            pagePreferenceSyncID <- Self.pagePreferenceSyncID(forPageKey: preference.pageKey),
            pagePreferenceHidesReadContent <- preference.hidesReadContent,
            pagePreferenceUserModifiedAt <- preference.userModifiedAt.timeIntervalSince1970,
            pagePreferenceNeedsSync <- needsSync
        ))
    }

    private func rowToPagePreference(_ row: Row) -> PagePreference {
        PagePreference(
            pageKey: row[pagePreferenceKey],
            hidesReadContent: row[pagePreferenceHidesReadContent],
            userModifiedAt: Date(timeIntervalSince1970: row[pagePreferenceUserModifiedAt])
        )
    }
}
