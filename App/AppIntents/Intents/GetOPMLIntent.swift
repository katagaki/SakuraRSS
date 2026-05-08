import AppIntents
import Foundation

struct GetOPMLIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("GetOPML.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("GetOPML.Description", table: "AppIntents")
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Export feeds as OPML")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let database = DatabaseManager.shared
        let feeds = ((try? database.allFeeds()) ?? []).filter { $0.isOPMLPortable }
        let opml = OPMLManager.shared.generateOPML(from: feeds)
        return .result(value: opml)
    }
}
