import EnhancedNavigation
import SwiftUI

private struct BrowserOverlayPageReporterKey: EnvironmentKey {
    static let defaultValue: ((UUID, BrowserOverlayPage?) -> Void)? = nil
}

extension EnvironmentValues {
    var browserOverlayPageReporter: ((UUID, BrowserOverlayPage?) -> Void)? {
        get { self[BrowserOverlayPageReporterKey.self] }
        set { self[BrowserOverlayPageReporterKey.self] = newValue }
    }
}

private struct BrowserOverlayPageModifier<Item: Equatable>: ViewModifier {

    @Environment(\.browserOverlayPageReporter) private var reporter
    @State private var overlayID = UUID()
    @Binding var item: Item?
    let identity: (Item) -> BrowserPageIdentity

    func body(content: Content) -> some View {
        content
            .onChange(of: item, initial: true) { _, newItem in
                guard let newItem else {
                    reporter?(overlayID, nil)
                    return
                }
                reporter?(overlayID, BrowserOverlayPage(
                    id: overlayID,
                    identity: identity(newItem),
                    dismiss: { item = nil }
                ))
            }
    }
}

extension View {
    /// Reports a page the enclosing view pushes by binding rather than by
    /// path. Applied next to the `navigationDestination(item:)` it describes.
    func browserOverlayPage<Item: Equatable>(
        item: Binding<Item?>,
        identity: @escaping (Item) -> BrowserPageIdentity
    ) -> some View {
        modifier(BrowserOverlayPageModifier(item: item, identity: identity))
    }
}
