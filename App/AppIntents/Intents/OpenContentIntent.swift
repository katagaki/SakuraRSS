import AppIntents
import Foundation

extension Notification.Name {
    static let openArticleFromIntent = Notification.Name("OpenArticleFromIntent")
}

struct OpenContentIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("OpenContent.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("OpenContent.Description", table: "AppIntents")
    )

    static let openAppWhenRun: Bool = true

    @Parameter(
        title: LocalizedStringResource("OpenContent.Parameter.Article", table: "AppIntents")
    )
    var target: ArticleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .openArticleFromIntent,
            object: nil,
            userInfo: ["articleID": target.articleID]
        )
        return .result()
    }
}

extension OpenContentIntent: OpenIntent {}
