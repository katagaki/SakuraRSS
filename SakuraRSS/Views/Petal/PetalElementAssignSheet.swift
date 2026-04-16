import SwiftUI

/// Bottom sheet shown after the user taps a DOM element in the
/// picker.  Lists every recipe slot the element can be bound to.
///
/// Rendered as its own sheet (rather than a `.confirmationDialog`)
/// because on iPad the latter renders as a popover, which in turn
/// dismisses the parent builder sheet through the presentation
/// controller hierarchy.
struct PetalElementAssignSheet: View {

    let element: PetalElementPickerWebView.PickedElement
    let onAssign: (PetalRecipeField) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if !element.text.isEmpty {
                    Section {
                        Text(element.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(String(localized: "Picker.Assign.Preview", table: "Petal"))
                    }
                }
                Section {
                    ForEach(PetalRecipeField.allCases, id: \.self) { field in
                        Button {
                            onAssign(field)
                        } label: {
                            Text(field.localizedLabel)
                        }
                    }
                } header: {
                    Text(String(localized: "Picker.Assign.Title", table: "Petal"))
                } footer: {
                    Text(element.selector)
                        .font(.caption.monospaced())
                }
            }
            .navigationTitle(String(localized: "Picker.Assign.NavTitle", table: "Petal"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { onCancel() }
                }
            }
        }
    }
}
