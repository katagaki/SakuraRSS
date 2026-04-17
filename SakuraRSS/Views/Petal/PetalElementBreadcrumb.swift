import SwiftUI

/// Horizontal breadcrumb trail showing the ancestor chain from the
/// document root down to the currently-selected element, with a
/// trailing drill-in control that exposes the selected element's
/// direct visible children as menu items.
///
/// Tapping an ancestor segment drills *out* (selects that ancestor);
/// picking a child from the trailing menu drills *in*.
struct PetalElementBreadcrumb: View {

    typealias Info = PetalElementPickerWebView.ElementInfo

    let ancestors: [Info]           // immediate parent first
    let selected: Info
    let children: [Info]
    let onSelectAncestor: (Int) -> Void   // levels up (1 = parent)
    let onSelectChild: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            trail
            drillInControl
                .padding(.trailing, 16)
        }
    }

    private var trail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(orderedAncestors.indices, id: \.self) { idx in
                        segment(orderedAncestors[idx].selector, isCurrent: false) {
                            let levelsUp = orderedAncestors.count - idx
                            onSelectAncestor(levelsUp)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    segment(selected.selector, isCurrent: true) {}
                        .id("selected-segment")
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: selected.selector) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("selected-segment", anchor: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var drillInControl: some View {
        if children.isEmpty {
            Image(systemName: "chevron.down.circle")
                .font(.title3)
                .foregroundStyle(.quaternary)
        } else {
            Menu {
                Section(String(localized: "Picker.Children.Menu", table: "Petal")) {
                    ForEach(children.indices, id: \.self) { idx in
                        Button {
                            onSelectChild(idx)
                        } label: {
                            childLabel(children[idx])
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .accessibilityLabel(String(localized: "Picker.Children.A11y", table: "Petal"))
        }
    }

    @ViewBuilder
    private func childLabel(_ info: Info) -> some View {
        if info.text.isEmpty {
            Text(verbatim: info.selector)
        } else {
            Text(verbatim: "\(info.selector)  \(info.text)")
        }
    }

    private var orderedAncestors: [Info] {
        Array(ancestors.reversed())   // outermost first
    }

    @ViewBuilder
    private func segment(_ tag: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(tag)
                .font(.footnote.monospaced().weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        isCurrent
                            ? Color.accentColor.opacity(0.18)
                            : Color.secondary.opacity(0.08)
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }
}
