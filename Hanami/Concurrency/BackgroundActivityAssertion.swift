import Foundation

/// `performExpiringActivity` only holds its assertion for as long as its callback
/// is on the stack, so the callback has to block a thread. Reference-counting a
/// single shared assertion keeps that cost at one blocked thread no matter how
/// many concurrent operations ask for background time.
final class BackgroundActivityAssertion: @unchecked Sendable {

    static let shared = BackgroundActivityAssertion()

    private let lock = NSLock()
    private var activeCount = 0
    private var release: DispatchSemaphore?
    private var expirationHandlers: [UUID: @Sendable () -> Void] = [:]

    func acquire(reason: String, onExpiration: @escaping @Sendable () -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        expirationHandlers[token] = onExpiration
        activeCount += 1
        let startsAssertion = activeCount == 1
        if startsAssertion {
            release = DispatchSemaphore(value: 0)
        }
        let semaphore = release
        lock.unlock()
        guard startsAssertion, let semaphore else { return token }
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { [weak self] expired in
            if expired {
                self?.expire()
            } else {
                semaphore.wait()
            }
        }
        return token
    }

    func relinquish(_ token: UUID) {
        lock.lock()
        expirationHandlers[token] = nil
        activeCount = max(0, activeCount - 1)
        var semaphore: DispatchSemaphore?
        if activeCount == 0 {
            semaphore = release
            release = nil
        }
        lock.unlock()
        semaphore?.signal()
    }

    private func expire() {
        lock.lock()
        let handlers = Array(expirationHandlers.values)
        expirationHandlers.removeAll()
        lock.unlock()
        for handler in handlers {
            handler()
        }
    }
}
