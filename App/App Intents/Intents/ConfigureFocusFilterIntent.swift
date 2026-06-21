import AppIntents
import Foundation
import Hanami

struct ConfigureFocusFilterIntent: SetFocusFilterIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("FocusFilter.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("FocusFilter.Description", table: "AppIntents")
    )

    @Parameter(title: LocalizedStringResource("FocusFilter.Lists", table: "AppIntents"))
    var lists: [ListEntity]?

    @Parameter(title: LocalizedStringResource("FocusFilter.Sections", table: "AppIntents"))
    var sections: [FeedSectionEntity]?

    var displayRepresentation: DisplayRepresentation {
        let names = (lists ?? []).map(\.name) + (sections ?? []).map(\.name)
        guard !names.isEmpty else {
            return DisplayRepresentation(
                title: LocalizedStringResource("FocusFilter.Title", table: "AppIntents")
            )
        }
        return DisplayRepresentation(title: "\(names.joined(separator: ", "))")
    }

    func perform() async throws -> some IntentResult {
        let listIDs = Set((lists ?? []).map(\.listID))
        let sectionKeys = Set((sections ?? []).map(\.id))
        if listIDs.isEmpty && sectionKeys.isEmpty {
            FocusFilterStore.clear()
        } else {
            FocusFilterStore.save(listIDs: listIDs, sectionKeys: sectionKeys)
        }
        return .result()
    }
}
