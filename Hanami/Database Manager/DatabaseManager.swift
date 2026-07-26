import Foundation
@preconcurrency import SQLite

public nonisolated final class DatabaseManager: @unchecked Sendable {

    public static let shared = DatabaseManager()

    public static let databasePath: String = {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        return containerURL.appendingPathComponent("Sakura.feeds").path
    }()

    public private(set) var database: Connection
    private init() {
        do {
            database = try Connection(Self.databasePath)
            try Self.applyConnectionPragmas(database)
            try createTables()
            fixupIfVersionChanged()
            wipeSummaryHeadlinesIfPromptVersionChanged()
            invalidateStaleParserCache()
            migrateContentInsightsToggle()
            invalidateStaleSimilarContentCache()
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    /// Replaces the current database connection and re-creates tables.
    public func reconnect() throws {
        database = try Connection(Self.databasePath)
        try Self.applyConnectionPragmas(database)
        try createTables()
    }

    /// Enables WAL mode and raises busy timeout so reads don't stall behind writes.
    private static func applyConnectionPragmas(_ connection: Connection) throws {
        try connection.run("PRAGMA journal_mode = WAL")
        try connection.run("PRAGMA synchronous = NORMAL")
        connection.busyTimeout = 5.0
        applyDataProtection(atPath: databasePath)
    }

    /// Lowers the database file's data protection so a SQLite lock held while the
    /// device is locked in the background doesn't trigger a `0xdead10cc` watchdog
    /// kill. The WAL/SHM siblings must match the main file's protection class.
    static func applyDataProtection(atPath path: String) {
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]
        for suffix in ["", "-wal", "-shm"] {
            let filePath = path + suffix
            guard fileManager.fileExists(atPath: filePath) else { continue }
            try? fileManager.setAttributes(attributes, ofItemAtPath: filePath)
        }
    }

    private func invalidateStaleParserCache() {
        let key = "App.ParserVersion.HTMLContentExtractor"
        let stored = UserDefaults.standard.integer(forKey: key)
        if stored < ContentResolver.parserVersion {
            try? invalidateAllCachedArticleContent()
            UserDefaults.standard.set(ContentResolver.parserVersion, forKey: key)
        }
    }

    /// Collapses legacy intelligence toggles into `Intelligence.ContentInsights.Enabled`.
    private func migrateContentInsightsToggle() {
        let defaults = UserDefaults.standard
        let migratedKey = "Intelligence.ContentInsights.Migrated"
        guard !defaults.bool(forKey: migratedKey) else { return }
        let legacySimilar = defaults.bool(forKey: "Intelligence.SimilarContent.Enabled")
        let legacyTopics = defaults.bool(forKey: "Intelligence.TopicsPeople.Enabled")
        if legacySimilar || legacyTopics {
            defaults.set(true, forKey: "Intelligence.ContentInsights.Enabled")
        }
        defaults.removeObject(forKey: "Intelligence.SimilarContent.Enabled")
        defaults.removeObject(forKey: "Intelligence.TopicsPeople.Enabled")
        defaults.set(true, forKey: migratedKey)
    }

    /// Bumps the similar-content algorithm version and wipes the cache on upgrade.
    private func invalidateStaleSimilarContentCache() {
        let key = "Intelligence.SimilarContent.AlgorithmVersion"
        let current = 2   // v1: embedding-only; v2: hybrid embedding + entity Jaccard
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored < current else { return }
        UserDefaults.standard.set(current, forKey: key)
        Task.detached(priority: .utility) { [weak self] in
            try? self?.invalidateSimilarContentCache()
        }
    }

    private func fixupIfVersionChanged() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let current = "\(version).\(build)"
        let stored = UserDefaults.standard.string(forKey: "App.DatabaseVersion")
        if current != stored {
            fixup()
            UserDefaults.standard.set(current, forKey: "App.DatabaseVersion")
        }
    }
}
