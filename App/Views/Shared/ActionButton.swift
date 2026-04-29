import SwiftUI

struct ActionButton: View {

    let size: CGFloat = 48.0
    let systemImage: String
    var isLoading: Bool = false
    var isTinted: Bool = false
    let accessibilityLabel: String
    var glassID: String?
    var glassNamespace: Namespace.ID?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(isTinted ? .white : .primary)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                }
            }
            .frame(width: size, height: size)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(glassEffect, in: .circle)
        .modifier(OptionalGlassEffectID(id: glassID, namespace: glassNamespace))
        .disabled(isLoading)
        .accessibilityLabel(accessibilityLabel)
        .animation(.smooth.speed(2.0), value: isLoading)
        .animation(.smooth.speed(2.0), value: isTinted)
    }

    private var glassEffect: Glass {
        if isTinted {
            return .regular.tint(.accentColor).interactive()
        } else {
            return .regular.interactive()
        }
    }
}

private struct OptionalGlassEffectID: ViewModifier {
    let id: String?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let id, let namespace {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}
