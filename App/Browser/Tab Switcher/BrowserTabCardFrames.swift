import SwiftUI

enum BrowserTabZoom {
    static let coordinateSpace = "BrowserShell"
}

extension View {
    /// Reports the rect the page collapses onto, before the switcher is ever
    /// shown.
    func reportsTabCardFrame(id: UUID, to store: BrowserTabStore) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(
                        of: proxy.frame(in: .named(BrowserTabZoom.coordinateSpace)),
                        initial: true
                    ) { _, frame in
                        store.setCardFrame(frame, for: id)
                    }
            }
        }
    }
}
