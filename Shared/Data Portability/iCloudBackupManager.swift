import Foundation
@preconcurrency import SQLite
#if canImport(UIKit)
import UIKit
#endif

// swiftlint:disable:next type_name
final class iCloudBackupManager: @unchecked Sendable {

    static let shared = iCloudBackupManager()

    // MARK: - Backup Interval

    enum BackupInterval: Int, CaseIterable, Identifiable {
        case everyNight = 86400
        case every12Hours = 43200
        case every6Hours = 21600
        case off = 0

        var id: Int { rawValue }
    }

    // MARK: - Metadata

    struct BackupMetadata: Codable {
        let date: Date
        let appVersion: String
        let deviceName: String
        let feedCount: Int
        let articleCount: Int
    }

    // MARK: - iCloud Availability

    func isICloudAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Backup

    func backupNow() async throws {
        guard isICloudAvailable(),
              let containerURL = iCloudContainerURL() else {
            throw BackupError.iCloudUnavailable
        }

        let documentsURL = containerURL.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: documentsURL,
                                                 withIntermediateDirectories: true)

        let cleanedURL = try createCleanedBackup()
        defer { try? FileManager.default.removeItem(at: cleanedURL) }

        let destinationURL = documentsURL.appendingPathComponent("Sakura.feeds")

        // Replace atomically
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: cleanedURL, to: destinationURL)

        // Write metadata
        let metadata = try buildMetadata()
        let metadataURL = documentsURL.appendingPathComponent("backup-metadata.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL, options: .atomic)

        // Record last backup date
        UserDefaults.standard.set(Date().timeIntervalSince1970,
                                  forKey: "iCloudBackup.LastBackupDate")
    }

    /// Runs a backup if the user's chosen interval has elapsed since the last backup.
    /// The system already throttled us via `earliestBeginDate`, so we allow a
    /// 10% slack to avoid skipping a granted run over minor timing drift.
    func backupIfScheduled() async {
        let intervalRaw = UserDefaults.standard.integer(forKey: "iCloudBackup.Interval")
        let interval = BackupInterval(rawValue: intervalRaw) ?? .everyNight
        guard interval != .off else { return }
        guard isICloudAvailable() else { return }

        let lastBackup = UserDefaults.standard.double(forKey: "iCloudBackup.LastBackupDate")
        let elapsed = Date().timeIntervalSince1970 - lastBackup
        let threshold = Double(interval.rawValue) * 0.9
        guard elapsed >= threshold else { return }

        try? await backupNow()
    }

    // MARK: - Restore

    func hasBackup() async -> Bool {
        await backupMetadata() != nil
    }

    func backupMetadata() async -> BackupMetadata? {
        guard let containerURL = iCloudContainerURL() else { return nil }
        let metadataURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("backup-metadata.json")

        // Trigger download if needed
        if !FileManager.default.fileExists(atPath: metadataURL.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: metadataURL)
            // Wait briefly for download
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if FileManager.default.fileExists(atPath: metadataURL.path) { break }
            }
        }

        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BackupMetadata.self, from: data)
    }

    func restore() async throws {
        guard let containerURL = iCloudContainerURL() else {
            throw BackupError.iCloudUnavailable
        }

        let backupURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("Sakura.feeds")

        // Trigger download if needed
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.startDownloadingUbiquitousItem(at: backupURL)
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 500_000_000)
                if FileManager.default.fileExists(atPath: backupURL.path) { break }
            }
        }

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw BackupError.backupNotFound
        }

        let dbPath = DatabaseManager.databasePath
        let dbURL = URL(fileURLWithPath: dbPath)

        // Remove existing database files (main + WAL + SHM if present)
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: dbPath + suffix)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }

        // Copy backup to database location
        try FileManager.default.copyItem(at: backupURL, to: dbURL)

        // Reconnect DatabaseManager
        try DatabaseManager.shared.reconnect()
    }

    // MARK: - Last Backup Date

    var lastBackupDate: Date? {
        let timestamp = UserDefaults.standard.double(forKey: "iCloudBackup.LastBackupDate")
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Private

    private func iCloudContainerURL() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.tsubuzaki.SakuraRSS")
    }

    private func createCleanedBackup() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempDB = tempDir.appendingPathComponent("Sakura-backup.feeds")

        if FileManager.default.fileExists(atPath: tempDB.path) {
            try FileManager.default.removeItem(at: tempDB)
        }

        // Copy the live database file
        let sourceURL = URL(fileURLWithPath: DatabaseManager.databasePath)
        try FileManager.default.copyItem(at: sourceURL, to: tempDB)

        // Also copy WAL/SHM if they exist so the temp copy is complete
        for suffix in ["-wal", "-shm"] {
            let src = URL(fileURLWithPath: DatabaseManager.databasePath + suffix)
            let dst = tempDir.appendingPathComponent("Sakura-backup.feeds" + suffix)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            if FileManager.default.fileExists(atPath: src.path) {
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }

        // Open the temp copy and strip caches, then vacuum
        let connection = try Connection(tempDB.path)
        try connection.run("DELETE FROM image_cache")
        try connection.run("DELETE FROM summary_cache")
        try connection.run("VACUUM")

        // Clean up WAL/SHM from temp (VACUUM consolidates everything)
        for suffix in ["-wal", "-shm"] {
            let dst = tempDir.appendingPathComponent("Sakura-backup.feeds" + suffix)
            try? FileManager.default.removeItem(at: dst)
        }

        return tempDB
    }

    private func buildMetadata() throws -> BackupMetadata {
        let database = DatabaseManager.shared
        let feedCount = try database.totalFeedCount()
        let articleCount = try database.database.scalar(database.articles.count)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        #if os(iOS)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        return BackupMetadata(
            date: Date(),
            appVersion: version,
            deviceName: deviceName,
            feedCount: feedCount,
            articleCount: articleCount
        )
    }

    // MARK: - Errors

    enum BackupError: LocalizedError {
        case iCloudUnavailable
        case backupNotFound

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable: String(localized: "iCloudBackup.Unavailable", table: "DataManagement")
            case .backupNotFound: String(localized: "iCloudBackup.RestoreError", table: "DataManagement")
            }
        }
    }
}
