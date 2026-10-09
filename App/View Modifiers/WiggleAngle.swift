import SwiftUI

extension EnvironmentValues {
    @Entry var wiggleAngle: Angle = .zero
}

private struct WiggleRotationModifier: ViewModifier {

    @Environment(\.wiggleAngle) private var wiggleAngle
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content.rotationEffect(wiggleAngle, anchor: anchor)
    }
}

extension View {
    func wiggleRotation(anchor: UnitPoint = .center) -> some View {
        modifier(WiggleRotationModifier(anchor: anchor))
    }
}
