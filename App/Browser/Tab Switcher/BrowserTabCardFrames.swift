import SwiftUI

enum BrowserTabZoom {
    static let coordinateSpace = "BrowserShell"
}

extension View {
    /// Writes the card's frame into the store so the page knows what rect to
    /// collapse into, before the switcher is ever shown.
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
