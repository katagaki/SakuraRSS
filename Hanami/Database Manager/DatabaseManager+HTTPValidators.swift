import Foundation
@preconcurrency import SQLite

public nonisolated struct FeedHTTPValidators: Sendable, Equatable {
    public let fetchURL: String
    public let eTag: String?
    public let lastModified: String?
    public let bodyHash: String?

    public init(fetchURL: String, eTag: String?, lastModified: String?, bodyHash: String?) {
        self.fetchURL = fetchURL
        self.eTag = eTag
        self.lastModified = lastModified
        self.bodyHash = bodyHash
    }
}

public nonisolated extension DatabaseManager {

    func httpValidators(forFeedID id: Int64) throws -> FeedHTTPValidators? {
        guard let row = try database.pluck(feedHTTPValidators.filter(validatorFeedID == id)) else {
            return nil
        }
        return FeedHTTPValidators(
            fetchURL: row[validatorFetchURL],
            eTag: row[validatorETag],
            lastModified: row[validatorLastModified],
            bodyHash: row[validatorBodyHash]
        )
    }

    func saveHTTPValidators(_ validators: FeedHTTPValidators, forFeedID id: Int64) throws {
        try database.run(feedHTTPValidators.insert(or: .replace,
            validatorFeedID <- id,
            validatorFetchURL <- validators.fetchURL,
            validatorETag <- validators.eTag,
            validatorLastModified <- validators.lastModified,
            validatorBodyHash <- validators.bodyHash
        ))
    }

    /// Forces the next refresh of every feed to download and parse in full, so
    /// deleted articles come back even when the server reports no changes.
    func clearAllHTTPValidators() throws {
        try database.run(feedHTTPValidators.delete())
    }
}
