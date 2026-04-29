import SwiftUI

/// Represents the selected view in the Home tab title menu.
/// Can be a static section or a user-created list.
enum HomeSelection: Hashable, RawRepresentable {
    case section(HomeSection)
    case list(Int64)

    var rawValue: String {
        switch self {
        case .section(let section): "section.\(section.rawValue)"
        case .list(let id): "list.\(id)"
        }
    }

    init?(rawValue: String) {
        if rawValue.hasPrefix("section.") {
            let sectionRaw = String(rawValue.dropFirst("section.".count))
            if let section = HomeSection(rawValue: sectionRaw) {
                self = .section(section)
                return
            }
        } else if rawValue.hasPrefix("list.") {
            let idStr = String(rawValue.dropFirst("list.".count))
            if let id = Int64(idStr) {
                self = .list(id)
                return
            }
        }
        // Legacy: bare section names from before the HomeSelection wrapper.
        if let section = HomeSection(rawValue: rawValue) {
            self = .section(section)
            return
        }
        return nil
    }

    var localizedTitle: String {
        switch self {
        case .section(let section): section.localizedTitle
        case .list: ""
        }
    }

    var systemImage: String? {
        switch self {
        case .section(let section): section.systemImage
        case .list: nil
        }
    }
}
