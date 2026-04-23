import SwiftUI

/// Breadcrumb trail for the element picker with drill-in child menu.
struct PetalElementBreadcrumb: View {

    typealias Info = PetalElementPickerWebView.ElementInfo

    let ancestors: [Info]
    let selected: Info
    let children: [Info]
    let onSelectAncestor: (Int) -> Void
    let onSelectChild: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
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
                        drillInControl
                            .tint(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .onChange(of: selected.selector) { _, _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("selected-segment", anchor: .trailing)
                    }
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
        Array(ancestors.reversed())
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
