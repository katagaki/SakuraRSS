#if targetEnvironment(macCatalyst)
import SwiftUI

private struct StopsMediaOnWindowCloseModifier: ViewModifier {

    var isMainWindow = false
    var teardown: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .background {
                WindowSceneCapturer(isMainWindow: isMainWindow, teardown: teardown)
                    .frame(width: 0, height: 0)
            }
    }
}

extension View {

    func stopsMediaOnWindowClose(perform teardown: (() -> Void)? = nil) -> some View {
        modifier(StopsMediaOnWindowCloseModifier(teardown: teardown))
    }

    func stopsSharedMediaOnLastMainWindowClose() -> some View {
        modifier(StopsMediaOnWindowCloseModifier(isMainWindow: true))
    }
}
#endif
