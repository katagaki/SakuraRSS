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
        VStack(spacing: 0) {
            if let picked {
                PetalElementBreadcrumb(
                    ancestors: picked.ancestors,
                    selected: picked.selected,
                    children: picked.children,
                    onSelectAncestor: onSelectAncestor,
                    onSelectChild: onSelectChild
                )
                .padding(.vertical, 8)
                Divider()
            }
            actionRow
        }
        .background(.ultraThinMaterial)
        .safeAreaPadding(.bottom)
    }

    private var actionRow: some View {
        HStack(alignment: .center, spacing: 12) {
            summary
            Spacer(minLength: 8)
            PetalElementAssignMenu(recipe: $recipe, picked: picked)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var summary: some View {
        if let picked {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "<\(picked.selected.tag)>")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.primary)
                if !picked.selected.text.isEmpty {
                    Text(picked.selected.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        } else {
            Text(String(localized: "Picker.NoSelection", table: "Petal"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
