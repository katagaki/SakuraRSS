import SwiftUI

/// Picker chrome pinned to the bottom of the sheet:
/// breadcrumb trail on top, picked-element summary + "Assign to…"
/// menu on the bottom.  Shows a placeholder until the user taps
/// an element in the web view.
struct PetalElementPickerBottomBar: View {

    @Binding var recipe: PetalRecipe
    let picked: PetalElementPickerWebView.PickedElement?
    let onSelectAncestor: (Int) -> Void
    let onSelectChild: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let picked {
                PetalElementBreadcrumb(
                    ancestors: picked.ancestors,
                    selected: picked.selected,
                    children: picked.children,
                    onSelectAncestor: onSelectAncestor,
                    onSelectChild: onSelectChild
                )
                .padding(.vertical, 6)
                .compositingGroup()
                .glassEffect(.regular, in: .capsule)
            }
            actionRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .safeAreaPadding(.bottom)
    }

    private var actionRow: some View {
        HStack(alignment: .center, spacing: 12) {
            summary
            Spacer(minLength: 8)
            PetalElementAssignMenu(recipe: $recipe, picked: picked)
        }
    }

    @ViewBuilder
    private var summary: some View {
        if let picked {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: picked.selected.selector)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    if !picked.selected.text.isEmpty {
                        Text(picked.selected.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .glassEffect(.regular, in: .capsule)
        } else {
            Text(String(localized: "Picker.NoSelection", table: "Petal"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .compositingGroup()
                .glassEffect(.regular, in: .capsule)
        }
    }
}
