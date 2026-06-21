import Foundation

public nonisolated struct FocusFilter: Sendable, Equatable {
    public var listIDs: Set<Int64>
    public var sectionKeys: Set<String>
    public var isActive: Bool

    public init(listIDs: Set<Int64>, sectionKeys: Set<String>, isActive: Bool) {
        self.listIDs = listIDs
        self.sectionKeys = sectionKeys
        self.isActive = isActive
    }

    public static let inactive = FocusFilter(listIDs: [], sectionKeys: [], isActive: false)

    public var isEmpty: Bool { listIDs.isEmpty && sectionKeys.isEmpty }
}

public nonisolated enum FocusFilterStore {

    private static let listIDsKey = "Focus.ActiveListIDs"
    private static let sectionKeysKey = "Focus.ActiveSectionKeys"
    private static let isActiveKey = "Focus.IsActive"

    public static func load() -> FocusFilter {
        let defaults = UserDefaults.standard
        let listIDs = Set((defaults.array(forKey: listIDsKey) as? [Int] ?? []).map(Int64.init))
        let sectionKeys = Set(defaults.stringArray(forKey: sectionKeysKey) ?? [])
        let isActive = defaults.bool(forKey: isActiveKey)
        return FocusFilter(listIDs: listIDs, sectionKeys: sectionKeys, isActive: isActive)
    }

    public static func save(listIDs: Set<Int64>, sectionKeys: Set<String>) {
        let defaults = UserDefaults.standard
        defaults.set(listIDs.map(Int.init), forKey: listIDsKey)
        defaults.set(Array(sectionKeys), forKey: sectionKeysKey)
        defaults.set(true, forKey: isActiveKey)
    }

    public static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: listIDsKey)
        defaults.removeObject(forKey: sectionKeysKey)
        defaults.set(false, forKey: isActiveKey)
    }
}
