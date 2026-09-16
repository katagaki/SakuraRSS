import AppIntents
import Foundation
import Hanami
import UniformTypeIdentifiers

struct ExportBookmarksIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("ExportBookmarks.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("ExportBookmarks.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("ExportBookmarks.Parameter.Format", table: "AppIntents"),
        default: .json
    )
    var format: BookmarkExportFormatAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Export bookmarks as \(\.$format)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let items = (try? DatabaseManager.shared.exportableBookmarks()) ?? []
        let contents = BookmarkExporter.export(
            items,
            as: format.exportFormat,
            unsortedFolderName: String(localized: "Bookmarks.Unsorted", table: "Articles")
        )
        let file = IntentFile(
            data: Data(contents.utf8),
            filename: "bookmarks.\(format.exportFormat.fileExtension)",
            type: format.contentType
        )
        return .result(value: file)
    }
}
