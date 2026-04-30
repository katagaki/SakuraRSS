import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func contentOverride(forFeedID fid: Int64) throws -> ContentOverride? {
        guard let row = try database.pluck(contentOverrides.filter(coFeedID == fid)) else {
            return nil
        }
        return rowToContentOverride(row)
    }

    func upsertContentOverride(_ override: ContentOverride) throws {
        try database.run(contentOverrides.insert(
            or: .replace,
            coFeedID <- override.feedID,
            coEnabled <- override.enabled,
            coTitleField <- override.titleField.rawValue,
            coBodyField <- override.bodyField.rawValue,
            coAuthorField <- override.authorField.rawValue
        ))
    }

    func deleteContentOverride(forFeedID fid: Int64) throws {
        try database.run(contentOverrides.filter(coFeedID == fid).delete())
    }

    func allContentOverrides() throws -> [ContentOverride] {
        try database.prepare(contentOverrides).map(rowToContentOverride)
    }

    private func rowToContentOverride(_ row: Row) -> ContentOverride {
        ContentOverride(
            feedID: row[coFeedID],
            enabled: row[coEnabled],
            titleField: ContentOverrideField(rawValue: row[coTitleField]) ?? .default,
            bodyField: ContentOverrideField(rawValue: row[coBodyField]) ?? .default,
            authorField: ContentOverrideField(rawValue: row[coAuthorField]) ?? .default
        )
    }
}
