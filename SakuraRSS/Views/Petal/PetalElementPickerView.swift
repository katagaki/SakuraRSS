import SwiftUI

/// Element-picker sheet for assigning DOM selections to recipe fields.
struct PetalElementPickerView: View {

    @Binding var recipe: PetalRecipe
    let html: String
    @Environment(\.dismiss) private var dismiss

    @State private var pickedElement: PetalElementPickerWebView.PickedElement?
    @State private var controller = PetalElementPickerController()

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
        .interactiveDismissDisabled()
    }
}
