import Foundation

/// Every recipe slot the element picker knows how to assign a
/// selector to.
enum PetalRecipeField: CaseIterable {
    case item, title, link, date, author, summary, image

    var localizedLabel: String {
        switch self {
        case .item:    String(localized: "Picker.Field.Item",    table: "Petal")
        case .title:   String(localized: "Picker.Field.Title",   table: "Petal")
        case .link:    String(localized: "Picker.Field.Link",    table: "Petal")
        case .date:    String(localized: "Picker.Field.Date",    table: "Petal")
        case .author:  String(localized: "Picker.Field.Author",  table: "Petal")
        case .summary: String(localized: "Picker.Field.Summary", table: "Petal")
        case .image:   String(localized: "Picker.Field.Image",   table: "Petal")
        }
    }

    /// Current selector stored in the recipe for this field, if any.
    func selector(in recipe: PetalRecipe) -> String? {
        let value: String?
        switch self {
        case .item:    value = recipe.itemSelector
        case .title:   value = recipe.titleSelector
        case .link:    value = recipe.linkSelector
        case .date:    value = recipe.dateSelector
        case .author:  value = recipe.authorSelector
        case .summary: value = recipe.summarySelector
        case .image:   value = recipe.imageSelector
        }
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Writes `selector` into this field on the recipe.
    func assign(_ selector: String, to recipe: inout PetalRecipe) {
        switch self {
        case .item:    recipe.itemSelector = selector
        case .title:   recipe.titleSelector = selector
        case .link:    recipe.linkSelector = selector
        case .date:    recipe.dateSelector = selector
        case .author:  recipe.authorSelector = selector
        case .summary: recipe.summarySelector = selector
        case .image:   recipe.imageSelector = selector
        }
    }
}
