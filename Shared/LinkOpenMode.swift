import Foundation

nonisolated enum LinkOpenMode: String, CaseIterable, Identifiable, Sendable {
    case browser
    case inAppViewer

    static let storageKey = "Reading.LinkOpenMode"
    var id: String { rawValue }
}
