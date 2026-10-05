import Hanami
import SwiftUI
import UniformTypeIdentifiers

/// Exported bookmarks as a file to save, in the format's own type.
struct BookmarkExportDocument: FileDocument {

    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] {
        BookmarkExportFormat.allCases.map(\.contentType)
    }

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration _: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

nonisolated extension BookmarkExportFormat {

    var contentType: UTType {
        switch self {
        case .json: .json
        case .csv: .commaSeparatedText
        case .html: .html
        case .markdown: UTType("net.daringfireball.markdown") ?? .plainText
        }
    }
}
