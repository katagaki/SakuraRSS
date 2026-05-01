import SwiftUI

/// Represents the selected view in the Home tab title menu.
/// Can be a static section, a user-created list, or a top topic.
enum HomeSelection: Hashable, RawRepresentable {
    case section(HomeSection)
    case list(Int64)
    case topic(String)

    var rawValue: String {
        switch self {
        case .section(let section): "section.\(section.rawValue)"
        case .list(let id): "list.\(id)"
        case .topic(let name): "topic.\(name)"
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
        } else if rawValue.hasPrefix("topic.") {
            let name = String(rawValue.dropFirst("topic.".count))
            if !name.isEmpty {
                self = .topic(name)
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
        case .topic(let name): name
        }
    }

    var systemImage: String? {
        switch self {
        case .section(let section): section.systemImage
        case .list: nil
        case .topic: "tag"
        }
    }
}
