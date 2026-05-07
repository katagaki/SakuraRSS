import AppIntents
import Foundation

struct GetTopicsAndPeopleIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("GetTopicsAndPeople.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("GetTopicsAndPeople.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("GetTopicsAndPeople.Parameter.Count", table: "AppIntents"),
        default: 10,
        inclusiveRange: (1, 100)
    )
    var count: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get top \(\.$count) topics and people")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[TopicPeopleEntity]> {
        let entities = await TopicPeopleQuery.loadTop(limit: count)
        return .result(value: entities)
    }
}
