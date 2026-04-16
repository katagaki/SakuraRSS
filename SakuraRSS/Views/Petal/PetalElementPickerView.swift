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

    private var baseURL: URL? {
        URL(string: recipe.baseURL ?? recipe.siteURL)
    }

    var body: some View {
        NavigationStack {
            PetalElementPickerWebView(
                html: html,
                baseURL: baseURL,
                onElementPicked: { pickedElement = $0 }
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
            .confirmationDialog(
                String(localized: "Picker.Assign.Title", table: "Petal"),
                isPresented: Binding(
                    get: { pickedElement != nil },
                    set: { if !$0 { pickedElement = nil } }
                ),
                titleVisibility: .visible
            ) {
                assignmentButtons
            } message: {
                if let el = pickedElement, !el.text.isEmpty {
                    Text(el.text)
                }
            }
        }
    }

    // MARK: - Assignment buttons

    @ViewBuilder
    private var assignmentButtons: some View {
        if let el = pickedElement {
            Button(fieldLabel(.item)) {
                recipe.itemSelector = el.selector
                pickedElement = nil
            }
            Button(fieldLabel(.title)) {
                recipe.titleSelector = el.selector
                pickedElement = nil
            }
            Button(fieldLabel(.link)) {
                recipe.linkSelector = el.selector
                pickedElement = nil
            }
            Button(fieldLabel(.date)) {
                recipe.dateSelector = el.selector
                pickedElement = nil
            }
            Button(fieldLabel(.author)) {
                recipe.authorSelector = el.selector
                pickedElement = nil
            }
            Button(fieldLabel(.summary)) {
                recipe.summarySelector = el.selector
                pickedElement = nil
            }
            Button(fieldLabel(.image)) {
                recipe.imageSelector = el.selector
                pickedElement = nil
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) {
                pickedElement = nil
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(field: .item, selector: recipe.itemSelector)
                chip(field: .title, selector: recipe.titleSelector ?? "")
                chip(field: .link, selector: recipe.linkSelector ?? "")
                chip(field: .date, selector: recipe.dateSelector ?? "")
                chip(field: .author, selector: recipe.authorSelector ?? "")
                chip(field: .summary, selector: recipe.summarySelector ?? "")
                chip(field: .image, selector: recipe.imageSelector ?? "")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .safeAreaPadding(.bottom)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private func chip(field: RecipeField, selector: String) -> some View {
        let isSet = !selector.isEmpty
        HStack(spacing: 4) {
            Image(systemName: isSet ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSet ? Color.green : Color.secondary)
            Text(fieldLabel(field))
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
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    isSet ? Color.green.opacity(0.35) : Color.secondary.opacity(0.2),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Helpers

    private func fieldLabel(_ field: RecipeField) -> String {
        switch field {
        case .item:    String(localized: "Picker.Field.Item",    table: "Petal")
        case .title:   String(localized: "Picker.Field.Title",   table: "Petal")
        case .link:    String(localized: "Picker.Field.Link",    table: "Petal")
        case .date:    String(localized: "Picker.Field.Date",    table: "Petal")
        case .author:  String(localized: "Picker.Field.Author",  table: "Petal")
        case .summary: String(localized: "Picker.Field.Summary", table: "Petal")
        case .image:   String(localized: "Picker.Field.Image",   table: "Petal")
        }
    }
}

// MARK: - RecipeField

private enum RecipeField {
    case item, title, link, date, author, summary, image
}
