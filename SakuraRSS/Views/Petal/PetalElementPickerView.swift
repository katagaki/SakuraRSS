import SwiftUI

/// Full-screen sheet that renders fetched HTML in a web view and
/// lets the user tap elements, navigate the DOM via a breadcrumb,
/// and assign the current selection to a recipe field via the
/// "Assign to…" menu.  Recipe mutations flow through the binding
/// so the builder sees them as soon as the sheet is dismissed.
struct PetalElementPickerView: View {

    @Binding var recipe: PetalRecipe
    let html: String
    @Environment(\.dismiss) private var dismiss

    @State private var pickedElement: PetalElementPickerWebView.PickedElement?
    @StateObject private var controller = PetalElementPickerController()

    private var baseURL: URL? {
        URL(string: recipe.baseURL ?? recipe.siteURL)
    }

    var body: some View {
        NavigationStack {
            PetalElementPickerWebView(
                html: html,
                baseURL: baseURL,
                controller: controller,
                onElementPicked: { pickedElement = $0 }
            )
            .ignoresSafeArea()
            .navigationTitle(String(localized: "Picker.Title", table: "Petal"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PetalElementPickerBottomBar(
                    recipe: $recipe,
                    picked: pickedElement,
                    onSelectAncestor: controller.selectAncestor(levelsUp:),
                    onSelectChild: controller.selectChild(atIndex:)
                )
            }
        }
    }
}
