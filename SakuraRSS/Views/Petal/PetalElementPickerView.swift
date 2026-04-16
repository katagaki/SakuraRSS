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
                    chip(field: .item)
                    chip(field: .title)
                    chip(field: .link)
                    chip(field: .date)
                    chip(field: .author)
                    chip(field: .summary)
                    chip(field: .image)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .safeAreaPadding(.bottom)
    }

    @ViewBuilder
    private func chip(field: PetalRecipeField) -> some View {
        let currentSelector = selector(for: field)
        let isSet = !currentSelector.isEmpty
        let canAssign = pickedElement != nil
        Button {
            if let el = pickedElement {
                assign(field: field, selector: el.selector)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSet ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSet ? Color.green : Color.secondary)
                Text(field.localizedLabel)
                    .font(.subheadline)
                    .foregroundStyle(isSet ? Color.primary : Color.secondary)
                if isSet {
                    Text(currentSelector)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(!canAssign)
    }

    private func selector(for field: PetalRecipeField) -> String {
        switch field {
        case .item:    recipe.itemSelector
        case .title:   recipe.titleSelector ?? ""
        case .link:    recipe.linkSelector ?? ""
        case .date:    recipe.dateSelector ?? ""
        case .author:  recipe.authorSelector ?? ""
        case .summary: recipe.summarySelector ?? ""
        case .image:   recipe.imageSelector ?? ""
        }
    }

}

