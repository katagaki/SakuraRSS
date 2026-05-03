import SwiftUI

struct OptionalGlassEffectID: ViewModifier {
    let id: String?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        #if os(visionOS)
        content
        #else
        if let id, let namespace {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
        #endif
    }
}

extension View {
    func optionalGlassEffectID(_ id: String?, in namespace: Namespace.ID?) -> some View {
        modifier(OptionalGlassEffectID(id: id, namespace: namespace))
    }
}
