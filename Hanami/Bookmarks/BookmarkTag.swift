import Foundation

public nonisolated struct BookmarkTag: Identifiable, Hashable, Sendable {

    public let id: Int64
    public var name: String
    /// Tags Sakura applied on the user's behalf when the bookmark was saved.
    /// They keep a fresh collection organized without asking for setup, and
    /// stop being automatic the moment the user edits one.
    public var isAutomatic: Bool

    public init(id: Int64, name: String, isAutomatic: Bool = false) {
        self.id = id
        self.name = name
        self.isAutomatic = isAutomatic
    }

    public static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
