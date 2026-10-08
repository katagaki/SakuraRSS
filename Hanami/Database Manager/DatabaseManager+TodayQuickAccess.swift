import Foundation
@preconcurrency import SQLite

public nonisolated struct TodayQuickAccessSettings: Sendable, Equatable {
    public var order: [String]
    public var hiddenIDs: Set<String>

    public static let empty = TodayQuickAccessSettings(order: [], hiddenIDs: [])
}

public nonisolated extension DatabaseManager {

    var todayQuickAccess: Table { Table("today_quick_access") }
    var todayQuickAccessItemID: SQLite.Expression<String> { SQLite.Expression<String>("item_id") }
    var todayQuickAccessSortOrder: SQLite.Expression<Int?> { SQLite.Expression<Int?>("sort_order") }
    var todayQuickAccessIsHidden: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_hidden") }

    func createTodayQuickAccessTable() throws {
        try database.run(todayQuickAccess.create(ifNotExists: true) { table in
            table.column(todayQuickAccessItemID, primaryKey: true)
            table.column(todayQuickAccessSortOrder)
            table.column(todayQuickAccessIsHidden, defaultValue: false)
        })
    }

    func todayQuickAccessSettings() throws -> TodayQuickAccessSettings {
        var orderedIDs: [(id: String, sortOrder: Int)] = []
        var hiddenIDs = Set<String>()
        for row in try database.prepare(todayQuickAccess) {
            let itemID = row[todayQuickAccessItemID]
            if let sortOrder = row[todayQuickAccessSortOrder] {
                orderedIDs.append((itemID, sortOrder))
            }
            if row[todayQuickAccessIsHidden] {
                hiddenIDs.insert(itemID)
            }
        }
        let order = orderedIDs.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        return TodayQuickAccessSettings(order: order, hiddenIDs: hiddenIDs)
    }

    func saveTodayQuickAccessSettings(_ settings: TodayQuickAccessSettings) throws {
        let sortOrders = Dictionary(
            settings.order.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let itemIDs = Set(sortOrders.keys).union(settings.hiddenIDs)
        try database.transaction {
            try database.run(todayQuickAccess.delete())
            for itemID in itemIDs {
                try database.run(todayQuickAccess.insert(
                    todayQuickAccessItemID <- itemID,
                    todayQuickAccessSortOrder <- sortOrders[itemID],
                    todayQuickAccessIsHidden <- settings.hiddenIDs.contains(itemID)
                ))
            }
        }
    }
}
