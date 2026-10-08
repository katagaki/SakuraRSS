import Foundation
@preconcurrency import SQLite

public nonisolated struct TodayShortcutSettings: Sendable, Equatable {
    public var order: [String]
    public var hiddenIDs: Set<String>

    public static let empty = TodayShortcutSettings(order: [], hiddenIDs: [])
}

public nonisolated extension DatabaseManager {

    var todayShortcuts: Table { Table("today_shortcuts") }
    var todayShortcutID: SQLite.Expression<String> { SQLite.Expression<String>("shortcut_id") }
    var todayShortcutSortOrder: SQLite.Expression<Int?> { SQLite.Expression<Int?>("sort_order") }
    var todayShortcutIsHidden: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_hidden") }

    func createTodayShortcutsTable() throws {
        try database.run(todayShortcuts.create(ifNotExists: true) { table in
            table.column(todayShortcutID, primaryKey: true)
            table.column(todayShortcutSortOrder)
            table.column(todayShortcutIsHidden, defaultValue: false)
        })
    }

    func todayShortcutSettings() throws -> TodayShortcutSettings {
        var orderedIDs: [(id: String, sortOrder: Int)] = []
        var hiddenIDs = Set<String>()
        for row in try database.prepare(todayShortcuts) {
            let shortcutID = row[todayShortcutID]
            if let sortOrder = row[todayShortcutSortOrder] {
                orderedIDs.append((shortcutID, sortOrder))
            }
            if row[todayShortcutIsHidden] {
                hiddenIDs.insert(shortcutID)
            }
        }
        let order = orderedIDs.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        return TodayShortcutSettings(order: order, hiddenIDs: hiddenIDs)
    }

    func saveTodayShortcutSettings(_ settings: TodayShortcutSettings) throws {
        let sortOrders = Dictionary(
            settings.order.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let shortcutIDs = Set(sortOrders.keys).union(settings.hiddenIDs)
        try database.transaction {
            try database.run(todayShortcuts.delete())
            for shortcutID in shortcutIDs {
                try database.run(todayShortcuts.insert(
                    todayShortcutID <- shortcutID,
                    todayShortcutSortOrder <- sortOrders[shortcutID],
                    todayShortcutIsHidden <- settings.hiddenIDs.contains(shortcutID)
                ))
            }
        }
    }
}
