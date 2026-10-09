import Foundation
import SQLite3
import Synchronization
@preconcurrency import SQLite

/// iOS kills a process that is suspended while it holds a SQLite lock in the
/// app group container (`0xdead10cc`). Once the last activity ends, the gate
/// interrupts running statements so their transactions roll back and release
/// the lock, then waits for each connection's queue to drain. The gate stays
/// closed only briefly so work after an untracked wake (such as a CloudKit
/// push) isn't blocked.
public nonisolated final class DatabaseSuspensionGate: @unchecked Sendable {

    public static let shared = DatabaseSuspensionGate()

    private static let closedDuration: Duration = .seconds(10)

    private let lock = NSLock()
    private var activityCount = 0
    private var connections: [WeakConnection] = []
    private var closedUntil: ContinuousClock.Instant?
    private let isClosedFlag = Atomic<Bool>(false)

    private init() {}

    var isClosed: Bool {
        guard isClosedFlag.load(ordering: .relaxed) else { return false }
        return lock.withLock {
            guard let closedUntil, ContinuousClock.now < closedUntil else {
                self.closedUntil = nil
                isClosedFlag.store(false, ordering: .relaxed)
                return false
            }
            return true
        }
    }

    func register(_ connection: Connection) {
        lock.withLock {
            connections.removeAll { $0.connection == nil }
            connections.append(WeakConnection(connection: connection))
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_progress_handler(connection.handle, 100, { context in
            guard let context else { return 0 }
            let gate = Unmanaged<DatabaseSuspensionGate>.fromOpaque(context).takeUnretainedValue()
            return gate.isClosed ? 1 : 0
        }, context)
    }

    public func beginActivity() {
        lock.withLock {
            activityCount += 1
            closedUntil = nil
            isClosedFlag.store(false, ordering: .relaxed)
        }
    }

    /// Blocks until running statements have been interrupted, so call it off
    /// the main thread before handing control back to the system.
    public func endActivity() {
        let registeredConnections: [Connection]? = lock.withLock {
            activityCount = max(0, activityCount - 1)
            guard activityCount == 0 else { return nil }
            closedUntil = ContinuousClock.now.advanced(by: Self.closedDuration)
            isClosedFlag.store(true, ordering: .relaxed)
            return connections.compactMap(\.connection)
        }
        guard let registeredConnections else { return }
        log("DatabaseSuspensionGate", "closing connections=\(registeredConnections.count)")
        for connection in registeredConnections {
            connection.interrupt()
            _ = try? connection.scalar("SELECT 1")
        }
    }
}

private nonisolated struct WeakConnection {
    weak var connection: Connection?
}
