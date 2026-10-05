import Foundation

public nonisolated struct ExportedBookmark: Sendable {
    public let title: String
    public let originalTitle: String
    public let url: String
    public let folder: String?
    public let tags: [String]
    public let savedDate: Date?
    public let isRead: Bool

    public init(
        title: String,
        originalTitle: String,
        url: String,
        folder: String?,
        tags: [String],
        savedDate: Date?,
        isRead: Bool
    ) {
        self.title = title
        self.originalTitle = originalTitle
        self.url = url
        self.folder = folder
        self.tags = tags
        self.savedDate = savedDate
        self.isRead = isRead
    }
}

public nonisolated enum BookmarkExportFormat: String, CaseIterable, Sendable {
    case json
    case csv
    case html
    case markdown

    public var fileExtension: String {
        switch self {
        case .json: "json"
        case .csv: "csv"
        case .html: "html"
        case .markdown: "md"
        }
    }
}
