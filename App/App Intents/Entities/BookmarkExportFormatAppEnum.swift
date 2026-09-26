import AppIntents
import Hanami
import UniformTypeIdentifiers

enum BookmarkExportFormatAppEnum: String, AppEnum {

    case json
    case csv
    case html
    case markdown

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("ExportBookmarks.Format", table: "AppIntents")
    )

    static let caseDisplayRepresentations: [BookmarkExportFormatAppEnum: DisplayRepresentation] = [
        .json: DisplayRepresentation(title: "JSON"),
        .csv: DisplayRepresentation(title: "CSV"),
        .html: DisplayRepresentation(title: "HTML"),
        .markdown: DisplayRepresentation(title: "Markdown")
    ]

    var exportFormat: BookmarkExportFormat {
        switch self {
        case .json: .json
        case .csv: .csv
        case .html: .html
        case .markdown: .markdown
        }
    }

    var contentType: UTType {
        switch self {
        case .json: .json
        case .csv: .commaSeparatedText
        case .html: .html
        case .markdown: UTType("net.daringfireball.markdown") ?? .plainText
        }
    }
}
