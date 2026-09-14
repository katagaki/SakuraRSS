import SwiftUI

/// Frames of the tab cards, reported so the page can collapse into the card it
/// belongs to rather than just shrinking on the spot.
struct BrowserTabCardFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

enum BrowserTabZoom {
    static let coordinateSpace = "BrowserShell"
}

extension View {
    func reportsTabCardFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BrowserTabCardFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(BrowserTabZoom.coordinateSpace))]
                )
            }
        }
    }
}
