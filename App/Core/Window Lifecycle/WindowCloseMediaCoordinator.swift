#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

/// SwiftUI does not reliably call `onDisappear` when a Catalyst window is
/// closed, so media teardown is driven by `UIScene.didDisconnectNotification`
/// observed from outside the closing window's view hierarchy.
final class WindowCloseMediaCoordinator {

    static let shared = WindowCloseMediaCoordinator()

    private final class Registration {
        weak var windowScene: UIWindowScene?
        weak var window: UIWindow?
        let isMainWindow: Bool
        var teardown: (() -> Void)?

        init(
            windowScene: UIWindowScene,
            window: UIWindow,
            isMainWindow: Bool,
            teardown: (() -> Void)?
        ) {
            self.windowScene = windowScene
            self.window = window
            self.isMainWindow = isMainWindow
            self.teardown = teardown
        }
    }

    private var registrations: [UUID: Registration] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidDisconnect(_:)),
            name: UIScene.didDisconnectNotification,
            object: nil
        )
    }

    func register(
        windowScene: UIWindowScene,
        window: UIWindow,
        isMainWindow: Bool,
        teardown: (() -> Void)?,
        replacing identifier: UUID?
    ) -> UUID {
        if let identifier {
            registrations.removeValue(forKey: identifier)
        }
        let newIdentifier = UUID()
        registrations[newIdentifier] = Registration(
            windowScene: windowScene,
            window: window,
            isMainWindow: isMainWindow,
            teardown: teardown
        )
        return newIdentifier
    }

    func updateTeardown(_ teardown: (() -> Void)?, for identifier: UUID) {
        registrations[identifier]?.teardown = teardown
    }

    @objc private func sceneDidDisconnect(_ notification: Notification) {
        guard let windowScene = notification.object as? UIWindowScene else { return }
        stopMedia(in: windowScene)
    }

    private func stopMedia(in windowScene: UIWindowScene) {
        var closedMainWindow = false
        for (identifier, registration) in registrations
        where registration.windowScene === windowScene || registration.windowScene == nil {
            if registration.windowScene === windowScene {
                WindowMediaSweeper.stopMedia(in: windowScene, capturedWindow: registration.window)
                registration.teardown?()
                closedMainWindow = closedMainWindow || registration.isMainWindow
            }
            registrations.removeValue(forKey: identifier)
        }
        let mainWindowsRemain = registrations.values.contains {
            $0.isMainWindow && $0.windowScene != nil
        }
        if closedMainWindow && !mainWindowsRemain {
            YouTubePlayerSession.shared.clear()
            AudioPlayer.shared.stop()
        }
    }
}
#endif
