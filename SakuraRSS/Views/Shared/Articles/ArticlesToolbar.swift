import SwiftUI

struct FloatingToolbarOverride: Equatable {
    let id: AnyHashable
    let alignment: HorizontalAlignment
    let content: AnyView

    static func == (lhs: FloatingToolbarOverride, rhs: FloatingToolbarOverride) -> Bool {
        lhs.id == rhs.id
    }
}

struct FloatingToolbarOverridePreferenceKey: PreferenceKey {
    static let defaultValue: FloatingToolbarOverride? = nil
    static func reduce(
        value: inout FloatingToolbarOverride?,
        nextValue: () -> FloatingToolbarOverride?
    ) {
        if let next = nextValue() {
            value = next
        }
    }
}

extension View {
    /// Lets a descendant replace the floating Mark As Read toolbar with its
    /// own content (e.g. article action buttons) while the descendant is on
    /// screen. The replacement renders inside the same `GlassEffectContainer`
    /// so glass elements morph between states.
    ///
    /// Pass an `id` that changes whenever the rendered content should refresh
    /// (e.g. include relevant state values in the id).
    func overrideFloatingToolbar<Content: View>(
        id: AnyHashable,
        alignment: HorizontalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        preference(
            key: FloatingToolbarOverridePreferenceKey.self,
            value: FloatingToolbarOverride(
                id: id,
                alignment: alignment,
                content: AnyView(content())
            )
        )
    }
}

struct ArticlesToolbar: View {

    var onMarkAllRead: () -> Void
    var override: FloatingToolbarOverride?
    @State private var isShowingMarkAllReadConfirmation = false
    @Namespace private var glassNamespace

    private var alignment: Alignment {
        guard let override else { return .leading }
        switch override.alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            Group {
                if let override {
                    override.content
                } else {
                    ActionButton(
                        systemImage: "envelope.open",
                        accessibilityLabel: String(localized: "MarkAllRead", table: "Articles"),
                        glassID: "articles.markAllRead",
                        glassNamespace: glassNamespace
                    ) {
                        isShowingMarkAllReadConfirmation = true
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment)
        }
        .animation(.smooth.speed(2.0), value: override?.id)
        .padding()
        .popover(isPresented: $isShowingMarkAllReadConfirmation) {
            VStack(spacing: 12) {
                Text(String(localized: "MarkAllRead.Confirm", table: "Articles"))
                    .font(.body)
                Button {
                    onMarkAllRead()
                    isShowingMarkAllReadConfirmation = false
                } label: {
                    Text(String(localized: "MarkAllRead", table: "Articles"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct MarkAllReadToolbarModifier: ViewModifier {
    let show: Bool
    let onMarkAllRead: () -> Void
    @State private var override: FloatingToolbarOverride?

    func body(content: Content) -> some View {
        Group {
            if show || override != nil {
                content.safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
                    ArticlesToolbar(onMarkAllRead: onMarkAllRead, override: override)
                }
            } else {
                content
            }
        }
        .onPreferenceChange(FloatingToolbarOverridePreferenceKey.self) { value in
            override = value
        }
    }
}

extension View {
    /// Attaches the floating Mark All Read button when `show` is true.
    /// A descendant may replace its content via `overrideFloatingToolbar`.
    func markAllReadToolbar(
        show: Bool,
        onMarkAllRead: @escaping () -> Void
    ) -> some View {
        modifier(MarkAllReadToolbarModifier(show: show, onMarkAllRead: onMarkAllRead))
    }
}
