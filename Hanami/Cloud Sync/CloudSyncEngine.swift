import CloudKit
import CryptoKit
import Foundation

public nonisolated final class CloudSyncEngine: @unchecked Sendable {

    public static let shared = CloudSyncEngine()

    public static let enabledDefaultsKey = "iCloudSync.Enabled"
    public static let lastSyncedAtDefaultsKey = "iCloudSync.LastSyncedAt"
    public static let didMigrateItemStatusesKey = "iCloudSync.DidMigrateItemStatuses"

    static let containerIdentifier = "iCloud.com.tsubuzaki.SakuraRSS"
    static let zoneName = "SakuraFeeds"
    static let feedRecordType = "Feed"
    static let itemStatusRecordType = "ItemStatus"
    static let itemStatusIDPrefix = "status."
    static let engineStateKey = "engineState"
    static let archivedRecordKeyPrefix = "record."

    static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    let database = DatabaseManager.shared

    public var onRemoteChangesApplied: (@Sendable (_ insertedNewFeeds: Bool) -> Void)?
    public var onRemoteFeedDeleted: (@Sendable (Feed) -> Void)?

    private let engineLock = NSLock()
    private var underlyingEngine: CKSyncEngine?
    private var itemStatusEnqueueScheduled = false

    var engine: CKSyncEngine? {
        engineLock.lock()
        defer { engineLock.unlock() }
        return underlyingEngine
    }

    public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    // MARK: - Lifecycle

    public func startIfEnabled() {
        guard Self.isEnabled else { return }
        start()
    }

    public func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled {
            start()
        } else {
            stop(clearingSyncMetadata: true)
        }
    }

    public func resetAfterRestore() {
        let wasRunning = engine != nil
        stop(clearingSyncMetadata: true)
        if wasRunning || Self.isEnabled {
            start()
        }
    }

    private func start() {
        engineLock.lock()
        guard underlyingEngine == nil else {
            engineLock.unlock()
            return
        }
        let stateSerialization = loadEngineState()
        let container = CKContainer(identifier: Self.containerIdentifier)
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: stateSerialization,
            delegate: self
        )
        let newEngine = CKSyncEngine(configuration)
        underlyingEngine = newEngine
        if stateSerialization == nil {
            queueInitialSync(on: newEngine)
        }
        engineLock.unlock()
        Task.detached { [weak self] in
            self?.migrateItemStatusesIfNeeded()
            self?.enqueueDirtyItemStatuses()
        }
        log("CloudSyncEngine", "Started (fresh state: \(stateSerialization == nil))")
    }

    func stop(clearingSyncMetadata: Bool) {
        engineLock.lock()
        underlyingEngine = nil
        engineLock.unlock()
        if clearingSyncMetadata {
            clearSyncMetadata()
        }
        log("CloudSyncEngine", "Stopped (cleared metadata: \(clearingSyncMetadata))")
    }

    func queueInitialSync(on engine: CKSyncEngine) {
        _ = try? database.backfillFeedSyncIDs()
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneName: Self.zoneName))])
        let feedSyncIDs = (try? database.allFeedSyncIDs()) ?? []
        engine.state.add(pendingRecordZoneChanges: feedSyncIDs.map { .saveRecord(Self.recordID(for: $0)) })
        let tombstoneIDs = (try? database.allSyncTombstoneIDs()) ?? []
        engine.state.add(pendingRecordZoneChanges: tombstoneIDs.map { .deleteRecord(Self.recordID(for: $0)) })
        log("CloudSyncEngine", "Queued initial sync: \(feedSyncIDs.count) feeds, \(tombstoneIDs.count) tombstones")
    }

    func clearSyncMetadata() {
        database.clearSyncEngineState()
        try? database.removeAllSyncTombstones()
    }

    // MARK: - Change Notifications

    public func noteFeedChanged(syncID: String?) {
        guard let syncID else { return }
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID(for: syncID))])
    }

    public func noteFeedDeleted(syncID: String?) {
        guard let syncID else { return }
        database.setSyncEngineStateData(nil, forKey: Self.archivedRecordKeyPrefix + syncID)
        engine?.state.add(pendingRecordZoneChanges: [.deleteRecord(Self.recordID(for: syncID))])
    }

    // MARK: - Item Status Sync

    /// Cheap hot-path hook: coalesces status writes into a single debounced
    /// background enqueue so marking items read never blocks the caller and
    /// bulk operations queue at most one upload pass.
    public func noteItemStatusChanged() {
        guard Self.isEnabled else { return }
        engineLock.lock()
        guard underlyingEngine != nil, !itemStatusEnqueueScheduled else {
            engineLock.unlock()
            return
        }
        itemStatusEnqueueScheduled = true
        engineLock.unlock()
        Task.detached { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.enqueueDirtyItemStatuses()
        }
    }

    func enqueueDirtyItemStatuses() {
        engineLock.lock()
        itemStatusEnqueueScheduled = false
        let engine = underlyingEngine
        engineLock.unlock()
        guard let engine else { return }
        let dirty = (try? database.dirtyItemStatuses()) ?? []
        guard !dirty.isEmpty else { return }
        let changes = dirty.map { change -> CKSyncEngine.PendingRecordZoneChange in
            let syncID = Self.itemStatusSyncID(forURL: change.url)
            database.setItemStatusSyncID(url: change.url, syncID: syncID)
            return .saveRecord(Self.recordID(for: syncID))
        }
        engine.state.add(pendingRecordZoneChanges: changes)
        database.clearItemStatusDirty(urls: dirty.map(\.url))
        log("CloudSyncEngine", "Enqueued \(changes.count) item statuses")
    }

    public func noteItemStatusesDeleted(syncIDs: [String]) {
        guard let engine, !syncIDs.isEmpty else { return }
        for syncID in syncIDs {
            database.setSyncEngineStateData(nil, forKey: Self.archivedRecordKeyPrefix + syncID)
        }
        engine.state.add(pendingRecordZoneChanges: syncIDs.map { .deleteRecord(Self.recordID(for: $0)) })
    }

    func migrateItemStatusesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.didMigrateItemStatusesKey) else { return }
        try? database.migrateItemStatusesForSync()
        UserDefaults.standard.set(true, forKey: Self.didMigrateItemStatusesKey)
        log("CloudSyncEngine", "Migrated existing item statuses for sync")
    }

    static func itemStatusSyncID(forURL url: String) -> String {
        let digest = SHA256.hash(data: Data(url.utf8))
        return itemStatusIDPrefix + digest.map { String(format: "%02x", $0) }.joined()
    }

    static func isItemStatusID(_ recordName: String) -> Bool {
        recordName.hasPrefix(itemStatusIDPrefix)
    }

    // MARK: - Manual Sync

    public func syncNow() async throws {
        guard let engine else { return }
        try await engine.sendChanges()
        try await engine.fetchChanges()
    }

    public func accountStatus() async -> CKAccountStatus {
        let container = CKContainer(identifier: Self.containerIdentifier)
        return (try? await container.accountStatus()) ?? .couldNotDetermine
    }

    // MARK: - Helpers

    static func recordID(for syncID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: syncID, zoneID: zoneID)
    }

    func markSynced() {
        UserDefaults.standard.set(Date(), forKey: Self.lastSyncedAtDefaultsKey)
    }

    private func loadEngineState() -> CKSyncEngine.State.Serialization? {
        guard let data = database.syncEngineStateData(forKey: Self.engineStateKey) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    func persistEngineState(_ stateSerialization: CKSyncEngine.State.Serialization) {
        guard let data = try? JSONEncoder().encode(stateSerialization) else { return }
        database.setSyncEngineStateData(data, forKey: Self.engineStateKey)
    }
}
