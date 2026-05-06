import AppIntents
import Foundation

enum ContentBlockKind: String, AppEnum {
    case text
    case image
    case code
    case video
    case audio
    case youtube
    case xPost
    case embed
    case table
    case math

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("ContentBlock.Kind", table: "AppIntents"))
    }

    static var caseDisplayRepresentations: [ContentBlockKind: DisplayRepresentation] {
        [
            .text: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Text", table: "AppIntents")),
            .image: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Image", table: "AppIntents")),
            .code: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Code", table: "AppIntents")),
            .video: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Video", table: "AppIntents")),
            .audio: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Audio", table: "AppIntents")),
            .youtube: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.YouTube", table: "AppIntents")),
            .xPost: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.XPost", table: "AppIntents")),
            .embed: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Embed", table: "AppIntents")),
            .table: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Table", table: "AppIntents")),
            .math: DisplayRepresentation(title: LocalizedStringResource("ContentBlock.Kind.Math", table: "AppIntents"))
        ]
    }
}

struct ContentBlockEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("ContentBlock", table: "AppIntents"))
    static let defaultQuery = ContentBlockEntityQuery()

    let id: String
    let kind: ContentBlockKind
    let text: String?
    let url: URL?

    init(block: ContentBlock) {
        self.id = block.id
        switch block {
        case .text(let value):
            self.kind = .text
            self.text = ContentBlock.stripMarkdown(value)
            self.url = nil
        case .code(let value):
            self.kind = .code
            self.text = value
            self.url = nil
        case .image(let resource, _):
            self.kind = .image
            self.text = nil
            self.url = resource
        case .video(let resource):
            self.kind = .video
            self.text = nil
            self.url = resource
        case .audio(let resource):
            self.kind = .audio
            self.text = nil
            self.url = resource
        case .youtube(let videoID):
            self.kind = .youtube
            self.text = videoID
            self.url = URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        case .xPost(let resource):
            self.kind = .xPost
            self.text = nil
            self.url = resource
        case .embed(_, let resource):
            self.kind = .embed
            self.text = nil
            self.url = resource
        case .table(let header, let rows):
            self.kind = .table
            let allRows = ([header] + rows).map { $0.joined(separator: " | ") }
            self.text = allRows.joined(separator: "\n")
            self.url = nil
        case .math(let latex):
            self.kind = .math
            self.text = latex
            self.url = nil
        }
    }

    var displayRepresentation: DisplayRepresentation {
        if let text, !text.isEmpty {
            DisplayRepresentation(title: "\(text.prefix(80))")
        } else if let url {
            DisplayRepresentation(title: "\(url.absoluteString)")
        } else {
            DisplayRepresentation(title: LocalizedStringResource("ContentBlock", table: "AppIntents"))
        }
    }
}

/// Stub query so `AppEntity` conformance is satisfied. Content blocks are
/// produced as intent output and aren't browsable on their own.
struct ContentBlockEntityQuery: EntityQuery {
    func entities(for identifiers: [ContentBlockEntity.ID]) async throws -> [ContentBlockEntity] { [] }
    func suggestedEntities() async throws -> [ContentBlockEntity] { [] }
}
