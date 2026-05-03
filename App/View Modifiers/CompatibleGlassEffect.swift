import SwiftUI

extension View {
    @ViewBuilder
    func compatibleGlassEffect<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        #if os(visionOS)
        self
        #else
        modifier(CompatibleGlassEffectModifier(shape: shape, tint: tint, interactive: interactive))
        #endif
    }

    @ViewBuilder
    func compatibleGlassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        #if os(visionOS)
        self
        #else
        glassEffectID(id, in: namespace)
        #endif
    }

    @ViewBuilder
    func compatibleGlassButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.bordered)
        #else
        buttonStyle(.glass)
        #endif
    }

    @ViewBuilder
    func compatibleGlassProminentButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.borderedProminent)
        #else
        buttonStyle(.glassProminent)
        #endif
    }

    @ViewBuilder
    func compatibleScrollEdgeEffectHidden() -> some View {
        #if os(visionOS)
        self
        #else
        scrollEdgeEffectHidden(true, for: .all)
        #endif
    }
}

#if !os(visionOS)
private struct CompatibleGlassEffectModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }

    private var glass: Glass {
        var result: Glass = .regular
        if let tint { result = result.tint(tint) }
        if interactive { result = result.interactive() }
        return result
    }
}
#endif

struct CompatibleGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        #if os(visionOS)
        content()
        #else
        GlassEffectContainer(spacing: spacing) {
            content()
        }
        #endif
    }
}
