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

    private var summary: some View {
        let selector = picked.map { Text(verbatim: $0.selected.selector) }
            ?? Text(String(localized: "Picker.NoSelection", table: "Petal"))
        let previewText = picked?.selected.text ?? ""
        return VStack(alignment: .leading, spacing: 2) {
            selector
                .font(picked != nil
                      ? .caption.monospaced().weight(.semibold)
                      : .subheadline)
                .foregroundStyle(picked != nil ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            Text(verbatim: previewText.isEmpty ? " " : previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(previewText.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .compositingGroup()
        .glassEffect(.regular, in: .capsule)
    }
}
