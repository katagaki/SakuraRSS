import AppIntents
import Foundation

struct AddFeedFromURLIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("AddFeedFromURL.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("AddFeedFromURL.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("AddFeedFromURL.Parameter.URL", table: "AppIntents")
    )
    var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Add feed from \(\.$url)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let database = DatabaseManager.shared
        let target = url

        if database.feedExists(url: target.absoluteString) {
            return .result(value: false)
        }

        let discovered = await FeedDiscovery.shared.discoverFeeds(fromPageURL: target)
        let candidate = discovered.first

        if let candidate {
            if database.feedExists(url: candidate.url) {
                return .result(value: false)
            }
            do {
                try database.insertFeed(
                    title: candidate.title,
                    url: candidate.url,
                    siteURL: candidate.siteURL
                )
                return .result(value: true)
            } catch {
                return .result(value: false)
            }
        }

        let host = target.host ?? ""
        let title = host.isEmpty ? target.absoluteString : host
        let siteURL = host.isEmpty
            ? target.absoluteString
            : "\(target.scheme ?? "https")://\(host)"
        do {
            try database.insertFeed(
                title: title,
                url: target.absoluteString,
                siteURL: siteURL
            )
            return .result(value: true)
        } catch {
            return .result(value: false)
        }
    }
}
