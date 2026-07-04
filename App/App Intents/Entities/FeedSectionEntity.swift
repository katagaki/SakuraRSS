import AppIntents
import Foundation
import Hanami

struct FeedSectionEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("FeedSectionFilter", table: "AppIntents"))
    static let defaultQuery = FeedSectionEntityQuery()

    let id: String
    let name: String

    init(section: FeedSection) {
        self.id = section.rawValue
        self.name = section.localizedTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FeedSectionEntityQuery: EntityQuery {

    func entities(for identifiers: [FeedSectionEntity.ID]) async throws -> [FeedSectionEntity] {
        let identifierSet = Set(identifiers)
        return FeedSection.allCases
            .filter { identifierSet.contains($0.rawValue) }
            .map(FeedSectionEntity.init(section:))
    }

    func suggestedEntities() async throws -> [FeedSectionEntity] {
        FeedSection.allCases.map(FeedSectionEntity.init(section:))
    }
}
