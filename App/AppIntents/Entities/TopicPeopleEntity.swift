import AppIntents
import Foundation

enum TopicPeopleKind: String, AppEnum {
    case topic
    case person

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("TopicPerson.Kind", table: "AppIntents"))
    }

    static var caseDisplayRepresentations: [TopicPeopleKind: DisplayRepresentation] {
        [
            .topic: DisplayRepresentation(
                title: LocalizedStringResource("TopicPerson.Kind.Topic", table: "AppIntents")
            ),
            .person: DisplayRepresentation(
                title: LocalizedStringResource("TopicPerson.Kind.Person", table: "AppIntents")
            )
        ]
    }
}

struct TopicPeopleEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("TopicPerson", table: "AppIntents"))
    static let defaultQuery = TopicPeopleQuery()

    /// Synthetic identifier shaped as `<kind>:<lowercased name>`
    /// so the Shortcuts picker can round-trip selections through `entities(for:)`.
    let id: String
    let kind: TopicPeopleKind
    let name: String
    let count: Int

    init(kind: TopicPeopleKind, name: String, count: Int) {
        self.id = "\(kind.rawValue):\(name.lowercased())"
        self.kind = kind
        self.name = name
        self.count = count
    }

    var entityTypes: [String] {
        switch kind {
        case .topic: return ["organization", "place"]
        case .person: return ["person"]
        }
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(count)"
        )
    }
}
