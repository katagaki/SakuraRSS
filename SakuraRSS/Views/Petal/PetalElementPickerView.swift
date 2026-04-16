import SwiftUI

/// Full-screen sheet that renders fetched HTML in a web view and
/// lets the user tap elements to assign them to recipe fields.
///
/// The picker modifies the recipe binding directly — changes are
/// visible in the builder as soon as the sheet is dismissed.
struct PetalElementPickerView: View {

    @Binding var recipe: PetalRecipe
    let html: String
    @Environment(\.dismiss) private var dismiss

    @State private var pickedElement: PetalElementPickerWebView.PickedElement?
    @State private var isAssignDialogPresented = false

    private var baseURL: URL? {
        URL(string: recipe.baseURL ?? recipe.siteURL)
    }

    var body: some View {
        NavigationStack {
            PetalElementPickerWebView(
                html: html,
                baseURL: baseURL,
                onElementPicked: { element in
                    pickedElement = element
                    isAssignDialogPresented = true
                }
            )
            .ignoresSafeArea()
            .navigationTitle(String(localized: "Picker.Title", table: "Petal"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Shared.Done")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                statusBar
            }
            .sheet(isPresented: $isAssignDialogPresented) {
                if let element = pickedElement {
                    PetalElementAssignSheet(
                        element: element,
                        onAssign: { field in
                            assign(field: field, selector: element.selector)
                            isAssignDialogPresented = false
                        },
                        onCancel: { isAssignDialogPresented = false }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Assignment

    private func assign(field: PetalRecipeField, selector: String) {
        switch field {
        case .item:    recipe.itemSelector = selector
        case .title:   recipe.titleSelector = selector
        case .link:    recipe.linkSelector = selector
        case .date:    recipe.dateSelector = selector
        case .author:  recipe.authorSelector = selector
        case .summary: recipe.summarySelector = selector
        case .image:   recipe.imageSelector = selector
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(field: .item, selector: recipe.itemSelector)
                    chip(field: .title, selector: recipe.titleSelector ?? "")
                    chip(field: .link, selector: recipe.linkSelector ?? "")
                    chip(field: .date, selector: recipe.dateSelector ?? "")
                    chip(field: .author, selector: recipe.authorSelector ?? "")
                    chip(field: .summary, selector: recipe.summarySelector ?? "")
                    chip(field: .image, selector: recipe.imageSelector ?? "")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .safeAreaPadding(.bottom)
    }

    @ViewBuilder
    private func chip(field: PetalRecipeField, selector: String) -> some View {
        let isSet = !selector.isEmpty
        HStack(spacing: 4) {
            Image(systemName: isSet ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSet ? Color.green : Color.secondary)
            Text(field.localizedLabel)
                .font(.subheadline)
                .foregroundStyle(isSet ? Color.primary : Color.secondary)
            if isSet {
                Text(selector)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

}

