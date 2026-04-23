import SwiftUI

/// "Assign to…" menu binding the picked element's selector to a recipe field.
struct PetalElementAssignMenu: View {

    @Binding var recipe: PetalRecipe
    let picked: PetalElementPickerWebView.PickedElement?

    var body: some View {
        Menu {
            ForEach(PetalRecipeField.allCases, id: \.self) { field in
                row(for: field)
            }
        } label: {
            HStack(spacing: 6) {
                Text(String(localized: "Picker.AssignTo", table: "Petal"))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxHeight: .infinity)
            .compositingGroup()
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .tint(.primary)
        .disabled(picked == nil)
    }

    @ViewBuilder
    private func row(for field: PetalRecipeField) -> some View {
        let current = field.selector(in: recipe)
        let pickedSelector = picked?.selected.selector
        let isAssignedToPicked = current != nil && current == pickedSelector
        Button {
            guard let pickedSelector else { return }
            field.assign(pickedSelector, to: &recipe)
        } label: {
            if isAssignedToPicked {
                Label(field.localizedLabel, systemImage: "checkmark")
            } else if let current {
                Text(verbatim: "\(field.localizedLabel) - \(current)")
            } else {
                Text(field.localizedLabel)
            }
        }
    }
}
