import Foundation
import Observation

/// `withObservationTracking` only reports the first change, so this tracks
/// again after every change until cancelled.
final class ChangeObserver {

    private let read: () -> Void
    private let onChange: () -> Void
    private var isCancelled = false

    init(tracking read: @escaping () -> Void, onChange: @escaping () -> Void) {
        self.read = read
        self.onChange = onChange
        track()
    }

    func cancel() {
        isCancelled = true
    }

    private func track() {
        guard !isCancelled else { return }
        withObservationTracking(read) { [weak self] in
            Task { @MainActor in
                guard let self, !self.isCancelled else { return }
                self.onChange()
                self.track()
            }
        }
    }
}
