import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private(set) var isOnline: Bool = true
    /// True when the active path is cellular, Personal Hotspot, or otherwise
    /// flagged as expensive by the system.  Callers use this to skip
    /// optional/cosmetic downloads during background refresh.
    private(set) var isExpensive: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor in
                self?.isOnline = online
                self?.isExpensive = expensive
            }
        }
        monitor.start(queue: queue)
    }

    /// One-shot path probe safe to call from non-MainActor contexts (e.g.
    /// the `BGAppRefreshTask` handler).  Spins up a short-lived monitor,
    /// awaits one path update, and returns.  Returns `nil` if no path is
    /// reported within the timeout — treat that as "assume expensive" at
    /// the call site.
    nonisolated static func currentPathIsExpensive(timeout: TimeInterval = 1.0) async -> Bool? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor.probe")
            var resumed = false
            let lock = NSLock()
            monitor.pathUpdateHandler = { path in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: path.isExpensive)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
}
