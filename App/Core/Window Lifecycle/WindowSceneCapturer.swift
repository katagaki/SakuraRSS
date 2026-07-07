#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

struct WindowSceneCapturer: UIViewRepresentable {

    var isMainWindow = false
    var teardown: (() -> Void)?

    func makeUIView(context: Context) -> WindowSceneCapturingView {
        let view = WindowSceneCapturingView()
        view.isMainWindow = isMainWindow
        view.teardown = teardown
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: WindowSceneCapturingView, context: Context) {
        uiView.teardown = teardown
        uiView.registerHostingSceneIfNeeded()
    }
}

final class WindowSceneCapturingView: UIView {

    var isMainWindow = false
    var teardown: (() -> Void)? {
        didSet {
            if let registrationIdentifier {
                WindowCloseMediaCoordinator.shared.updateTeardown(
                    teardown,
                    for: registrationIdentifier
                )
            }
        }
    }
    private var registrationIdentifier: UUID?
    private weak var registeredWindowScene: UIWindowScene?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        registerHostingSceneIfNeeded()
    }

    func registerHostingSceneIfNeeded() {
        guard let window, let windowScene = window.windowScene else { return }
        guard windowScene !== registeredWindowScene else { return }
        registeredWindowScene = windowScene
        registrationIdentifier = WindowCloseMediaCoordinator.shared.register(
            windowScene: windowScene,
            window: window,
            isMainWindow: isMainWindow,
            teardown: teardown,
            replacing: registrationIdentifier
        )
    }
}
#endif
