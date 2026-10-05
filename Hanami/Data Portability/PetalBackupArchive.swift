import Foundation
@preconcurrency import SQLite

nonisolated enum PetalBackupArchive {

    struct Entry: Sendable {
        let recipe: PetalRecipe
        let iconData: Data?
    }

    private static let table = Table("petal_backup_recipes")
    private static let recipeID = Expression<String>("id")
    private static let recipeData = Expression<Blob>("recipe_data")
    private static let iconData = Expression<Blob?>("icon_data")

    static func write(_ entries: [Entry], to connection: Connection) throws {
        try connection.run(table.create(ifNotExists: true) { builder in
            builder.column(recipeID, primaryKey: true)
            builder.column(recipeData)
            builder.column(iconData)
        })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try connection.transaction {
            try connection.run(table.delete())
            for entry in entries {
                let encodedRecipe = try encoder.encode(entry.recipe)
                try connection.run(table.insert(
                    recipeID <- entry.recipe.id.uuidString,
                    recipeData <- Blob(bytes: Array(encodedRecipe)),
                    iconData <- entry.iconData.map { Blob(bytes: Array($0)) }
                ))
            }
        }
    }

    static func read(from connection: Connection) throws -> [Entry] {
        let tableCount = try connection.scalar(
            "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'petal_backup_recipes'"
        ) as? Int64 ?? 0
        guard tableCount > 0 else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try connection.prepare(table).map { row in
            let recipe = try decoder.decode(PetalRecipe.self, from: Data(row[recipeData].bytes))
            guard recipe.version <= PetalRecipe.currentVersion else {
                throw CocoaError(.coderReadCorrupt)
            }
            return Entry(recipe: recipe, iconData: row[iconData].map { Data($0.bytes) })
        }
    }
}
