import Foundation

/// Every recipe slot the element picker knows how to assign a
/// selector to.  Shared between `PetalElementPickerView` (which
/// renders chips + decides where to write) and
/// `PetalElementAssignSheet` (which presents the menu).
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
}
