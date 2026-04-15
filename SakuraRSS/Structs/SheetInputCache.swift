import Foundation

/// Process-scoped cache for preserving in-progress user input in sheets
/// across view recreation.  SwiftUI @State on a sheet view can be torn
/// down and rebuilt when the app is backgrounded and returns to the
/// foreground (iOS may invalidate the sheet's snapshot, and subsequent
/// feedManager mutations re-run the view body).  Without this cache,
/// any half-typed URL / name / rules input is lost on every app switch.
///
/// Sheets read their initial @State from this cache in `init` via
/// `State(initialValue:)` and write back on every change.  The cache
/// entry is cleared on explicit save or cancel.
@MainActor
enum SheetInputCache {

    // MARK: - Add Feed

    static var addFeedURLInput: String = ""

    static func clearAddFeed() {
        addFeedURLInput = ""
    }

    // MARK: - Feed Edit

    struct FeedEditSnapshot {
        var name: String
        var url: String
        var iconURLInput: String
        var openModeRaw: String?
        var articleSourceRaw: String?
        var useDefaultIcon: Bool
    }

    private static var feedEdit: [Int64: FeedEditSnapshot] = [:]

    static func feedEditSnapshot(for feedID: Int64) -> FeedEditSnapshot? {
        feedEdit[feedID]
    }

    static func setFeedEditSnapshot(_ snapshot: FeedEditSnapshot, for feedID: Int64) {
        feedEdit[feedID] = snapshot
    }

    static func clearFeedEdit(for feedID: Int64) {
        feedEdit.removeValue(forKey: feedID)
    }

    // MARK: - Feed Rules

    struct FeedRulesSnapshot {
        var allowedKeywords: [String]
        var mutedKeywords: [String]
        var mutedAuthors: [String]
        var allowedKeywordInput: String
        var keywordInput: String
        var authorInput: String
    }

    private static var feedRules: [Int64: FeedRulesSnapshot] = [:]

    static func feedRulesSnapshot(for feedID: Int64) -> FeedRulesSnapshot? {
        feedRules[feedID]
    }

    static func setFeedRulesSnapshot(_ snapshot: FeedRulesSnapshot, for feedID: Int64) {
        feedRules[feedID] = snapshot
    }

    static func clearFeedRules(for feedID: Int64) {
        feedRules.removeValue(forKey: feedID)
    }

    // MARK: - List Edit

    struct ListEditSnapshot {
        var name: String
        var selectedIcon: String
        var selectedDisplayStyle: String?
        var selectedFeedIDs: Set<Int64>
    }

    /// Keyed by list id for edits of existing lists; `nil` key is used
    /// for a new (unsaved) list.
    private static var listEdit: [Int64?: ListEditSnapshot] = [:]

    static func listEditSnapshot(for listID: Int64?) -> ListEditSnapshot? {
        listEdit[listID]
    }

    static func setListEditSnapshot(_ snapshot: ListEditSnapshot, for listID: Int64?) {
        listEdit[listID] = snapshot
    }

    static func clearListEdit(for listID: Int64?) {
        listEdit.removeValue(forKey: listID)
    }

    // MARK: - List Rules

    struct ListRulesSnapshot {
        var allowedKeywords: [String]
        var mutedKeywords: [String]
        var mutedAuthors: [String]
        var allowedKeywordInput: String
        var keywordInput: String
        var authorInput: String
    }

    private static var listRules: [Int64: ListRulesSnapshot] = [:]

    static func listRulesSnapshot(for listID: Int64) -> ListRulesSnapshot? {
        listRules[listID]
    }

    static func setListRulesSnapshot(_ snapshot: ListRulesSnapshot, for listID: Int64) {
        listRules[listID] = snapshot
    }

    static func clearListRules(for listID: Int64) {
        listRules.removeValue(forKey: listID)
    }
}
