import SwiftUI

private struct WiggleGlassEffectModifier: ViewModifier {

    @Environment(\.wiggleAngle) private var wiggleAngle
    let shape: RoundedRectangle
    let tint: Color?
    let clear: Bool

    func body(content: Content) -> some View {
        #if os(visionOS)
        content.compatibleGlassEffect(in: shape, tint: tint, clear: clear)
        #else
        content.modifier(CompatibleGlassEffectModifier(
            shape: shape.rotation(wiggleAngle), tint: tint, interactive: false, clear: clear
        ))
        #endif
    }
}

extension View {
    func wiggleGlassEffect(in shape: RoundedRectangle, tint: Color? = nil, clear: Bool = false) -> some View {
        modifier(WiggleGlassEffectModifier(shape: shape, tint: tint, clear: clear))
    }
}
