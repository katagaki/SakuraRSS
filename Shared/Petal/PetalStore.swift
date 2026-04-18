import Foundation

/// On-disk store for `PetalRecipe` JSON files.
///
/// Recipes live in the shared app-group container alongside the SQLite
/// database so widgets and the share extension can read them.  Each
/// recipe is stored as a separate JSON file keyed by UUID, so editing
/// a Petal is a single-file write and corrupting one file can't take
/// the rest of the library with it.
///
/// ```
/// group.com.tsubuzaki.SakuraRSS/
///   Petals/
///     <uuid>.json
///     <uuid>.png       ← optional icon, imported from .srss packages
/// ```
nonisolated final class PetalStore: @unchecked Sendable {

    static let shared = PetalStore()

    private let directoryURL: URL
    private let iconDirectoryURL: URL

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        directoryURL = containerURL.appendingPathComponent("Petals", isDirectory: true)
        iconDirectoryURL = directoryURL
        try? FileManager.default.createDirectory(
            at: directoryURL, withIntermediateDirectories: true
        )
    }

    // MARK: - Recipes

    func save(_ recipe: PetalRecipe) throws {
        var copy = recipe
        copy.lastModified = Date()
        let data = try encoder.encode(copy)
        let url = directoryURL.appendingPathComponent("\(recipe.id.uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    func recipe(id: UUID) -> PetalRecipe? {
        let url = directoryURL.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PetalRecipe.self, from: data)
    }

    func recipe(forFeedURL feedURL: String) -> PetalRecipe? {
        guard let siteURL = PetalRecipe.siteURL(from: feedURL) else { return nil }
        return allRecipes().first { $0.siteURL == siteURL }
    }

    func allRecipes() -> [PetalRecipe] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(PetalRecipe.self, from: data)
            }
            .sorted { $0.lastModified > $1.lastModified }
    }

    func deleteRecipe(id: UUID) throws {
        let jsonURL = directoryURL.appendingPathComponent("\(id.uuidString).json")
        let iconURL = iconURL(for: id)
        try? FileManager.default.removeItem(at: jsonURL)
        try? FileManager.default.removeItem(at: iconURL)
    }

    // MARK: - Icons

    /// Path where the optional imported PNG icon for a recipe lives.
    /// Not every recipe has one - only those imported from `.srss`
    /// packages that included a feed icon.
    func iconURL(for id: UUID) -> URL {
        iconDirectoryURL.appendingPathComponent("\(id.uuidString).png")
    }

    func saveIcon(_ data: Data, for id: UUID) throws {
        try data.write(to: iconURL(for: id), options: .atomic)
    }

    func iconData(for id: UUID) -> Data? {
        try? Data(contentsOf: iconURL(for: id))
    }

    // MARK: - Coding

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
