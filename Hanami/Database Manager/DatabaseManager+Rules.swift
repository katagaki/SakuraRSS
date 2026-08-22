import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    // MARK: - Feed Rules CRUD

    func rules(forFeedID feedID: Int64, type: String) throws -> [String] {
        try database.prepare(
            feedRules
                .filter(ruleFeedID == feedID && ruleType == type)
                .order(ruleValue.asc)
        ).map { $0[ruleValue] }
    }

    func allRules(forFeedID feedID: Int64) throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        let query = feedRules
            .filter(ruleFeedID == feedID)
            .order(ruleValue.asc)
        for row in try database.prepare(query) {
            result[row[ruleType], default: []].append(row[ruleValue])
        }
        return result
    }

    func feedIDsWithRules() throws -> Set<Int64> {
        var result = Set<Int64>()
        for row in try database.prepare(feedRules.select(distinct: ruleFeedID)) {
            result.insert(row[ruleFeedID])
        }
        return result
    }

    @discardableResult
    func insertRule(feedID: Int64, type: String, value: String) throws -> Int64 {
        try database.run(feedRules.insert(
            ruleFeedID <- feedID,
            ruleType <- type,
            ruleValue <- value
        ))
    }

    func deleteRule(feedID: Int64, type: String, value: String) throws {
        let target = feedRules.filter(
            ruleFeedID == feedID && ruleType == type && ruleValue == value
        )
        try database.run(target.delete())
    }

    func replaceRules(feedID: Int64, type: String, values: [String]) throws {
        let existing = feedRules.filter(ruleFeedID == feedID && ruleType == type)
        try database.run(existing.delete())
        for value in values {
            try database.run(feedRules.insert(
                ruleFeedID <- feedID,
                ruleType <- type,
                ruleValue <- value
            ))
        }
    }

    func deleteAllRules(forFeedID feedID: Int64) throws {
        try database.run(feedRules.filter(ruleFeedID == feedID).delete())
    }
}
