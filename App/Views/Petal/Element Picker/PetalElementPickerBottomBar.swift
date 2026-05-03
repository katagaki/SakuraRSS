import SwiftUI

/// Bottom bar with breadcrumb trail and picked-element assign menu.
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
                .compatibleGlassEffect(in: .capsule)
            }
            HStack(alignment: .center, spacing: 12) {
                Group {
                    VStack(alignment: .leading, spacing: 2) {
                        Group {
                            if let picked {
                                Text(verbatim: picked.selected.selector)
                            } else {
                                Text(String(localized: "Picker.NoSelection", table: "Petal"))
                            }
                        }
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        Text(picked?.selected.text ?? "-")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .fixedSize(horizontal: false, vertical: true)
                .compositingGroup()
                .compatibleGlassEffect(in: .capsule)
                PetalElementAssignMenu(recipe: $recipe, picked: picked)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .safeAreaPadding(.bottom)
    }
}
