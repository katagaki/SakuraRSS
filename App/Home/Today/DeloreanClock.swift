import Foundation
import SwiftUI
import UIKit
import Hanami

/// Demo clock for the `sakura://delorean` deep link. While active, advances a
/// virtual time-of-day from 00:00 to 23:59 in a tight loop so observers
/// (currently the Today greeting + period color) cycle through the full day.
@Observable
@MainActor
final class DeloreanClock {

    static let shared = DeloreanClock()

    /// One full simulated day per this many wall-clock seconds.
    private static let cycleDurationSeconds: Double = 30
    private static let updateHz: Double = 30

    /// Simulated minutes since local midnight, or `nil` when the loop is off.
    /// Treated as the source of truth for the greeting + period color while set.
    private(set) var virtualMinutes: Double?

    private var task: Task<Void, Never>?
    private var lifecycleObservers: [any NSObjectProtocol] = []

    var isActive: Bool { virtualMinutes != nil }

    /// Real or simulated wall-clock used to derive greeting + gradient.
    var currentDate: Date {
        guard let virtualMinutes else { return Date() }
        let midnight = Calendar.current.startOfDay(for: Date())
        return midnight.addingTimeInterval(virtualMinutes * 60)
    }

    private init() {}

    func toggle() {
        if isActive { stop() } else { start() }
    }

    private func start() {
        stop()
        virtualMinutes = 0
        log("Delorean", "starting day cycle (\(Int(Self.cycleDurationSeconds))s per loop)")
        startLoop()
        observeLifecycle()
    }

    private func startLoop() {
        let increment = (24 * 60) / (Self.cycleDurationSeconds * Self.updateHz)
        let interval = 1.0 / Self.updateHz
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard let self, self.virtualMinutes != nil else { return }
                var next = (self.virtualMinutes ?? 0) + increment
                if next >= 24 * 60 { next -= 24 * 60 }
                self.virtualMinutes = next
            }
        }
    }

    private func stop() {
        guard isActive else { return }
        log("Delorean", "stopping day cycle")
        task?.cancel()
        task = nil
        virtualMinutes = nil
        removeLifecycleObservers()
    }

    private func observeLifecycle() {
        guard lifecycleObservers.isEmpty else { return }
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.pauseLoop() }
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.resumeLoopIfActive() }
            }
        ]
    }

    private func removeLifecycleObservers() {
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        lifecycleObservers = []
    }

    private func pauseLoop() {
        task?.cancel()
        task = nil
    }

    private func resumeLoopIfActive() {
        guard isActive, task == nil else { return }
        startLoop()
    }
}
