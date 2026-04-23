import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private(set) var isOnline: Bool = true
    /// True when the active path is flagged as expensive by the system.
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

    /// One-shot path probe safe from non-MainActor contexts; returns `nil` on timeout.
    nonisolated static func currentPathIsExpensive(timeout: TimeInterval = 1.0) async -> Bool? {
        final class ProbeState: @unchecked Sendable {
            var resumed = false
            let lock = NSLock()
        }
        let state = ProbeState()
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor.probe")
            monitor.pathUpdateHandler = { path in
                state.lock.lock()
                defer { state.lock.unlock() }
                guard !state.resumed else { return }
                state.resumed = true
                monitor.cancel()
                continuation.resume(returning: path.isExpensive)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                state.lock.lock()
                defer { state.lock.unlock() }
                guard !state.resumed else { return }
                state.resumed = true
                monitor.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
}
