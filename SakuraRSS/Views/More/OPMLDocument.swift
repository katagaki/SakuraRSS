import SwiftUI
import UniformTypeIdentifiers

struct OPMLDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.opml] }

    let content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(data: data, encoding: .utf8) ?? ""
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}

extension UTType {
    nonisolated static let opml = UTType("org.opml.opml") ?? UTType(filenameExtension: "opml", conformingTo: .xml)!
}
