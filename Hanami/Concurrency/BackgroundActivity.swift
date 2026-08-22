import Foundation

/// Runs `operation` while holding a background-execution assertion so the system
/// defers app suspension until the work finishes. This prevents the `0xdead10cc`
/// watchdog kill that occurs when the process is suspended while it still holds a
/// SQLite lock or an in-flight WAL checkpoint. If the assertion expires before the
/// work completes, the work is cancelled so the database connection is left with no
/// open transaction. Cancellation of the calling task is also forwarded.
func withBackgroundActivity<Value: Sendable>(
    reason: String,
    _ operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    let work = Task { try await operation() }
    let token = BackgroundActivityAssertion.shared.acquire(reason: reason) {
        work.cancel()
    }
    return try await withTaskCancellationHandler {
        defer { BackgroundActivityAssertion.shared.relinquish(token) }
        return try await work.value
    } onCancel: {
        work.cancel()
    }
}
