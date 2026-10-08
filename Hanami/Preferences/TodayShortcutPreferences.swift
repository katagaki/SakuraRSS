import Foundation
import Observation

/// Shortcuts missing from the saved order (new lists, newly followed feed
/// types) land after the ordered ones, in the order they were offered.
@MainActor
@Observable
public final class TodayShortcutPreferences {

    public static let shared = TodayShortcutPreferences()

    private static let orderKey = "Today.Shortcuts.Order"
    private static let hiddenKey = "Today.Shortcuts.Hidden"

    public private(set) var order: [String]
    public private(set) var hiddenIDs: Set<String>

    public var isCustomized: Bool {
        !order.isEmpty || !hiddenIDs.isEmpty
    }

    private init() {
        let defaults = UserDefaults.standard
        order = defaults.stringArray(forKey: Self.orderKey) ?? []
        hiddenIDs = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    public func ordered(_ items: [TodayShortcutItem]) -> [TodayShortcutItem] {
        let positions = Dictionary(
            order.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let savedItems = items
            .filter { positions[$0.id] != nil }
            .sorted { positions[$0.id, default: .max] < positions[$1.id, default: .max] }
        let unsavedItems = items.filter { positions[$0.id] == nil }
        return savedItems + unsavedItems
    }

    public func visible(_ items: [TodayShortcutItem]) -> [TodayShortcutItem] {
        ordered(items).filter { !hiddenIDs.contains($0.id) }
    }

    public func isHidden(_ item: TodayShortcutItem) -> Bool {
        hiddenIDs.contains(item.id)
    }

    public func setHidden(_ isHidden: Bool, for item: TodayShortcutItem) {
        if isHidden {
            hiddenIDs.insert(item.id)
        } else {
            hiddenIDs.remove(item.id)
        }
        UserDefaults.standard.set(Array(hiddenIDs), forKey: Self.hiddenKey)
    }

    /// Keeps saved positions for shortcuts not in `items` (such as ones a
    /// Focus is filtering out) so they don't drop to the end when they return.
    public func saveOrder(_ items: [TodayShortcutItem]) {
        let itemIDs = items.map(\.id)
        let reorderedIDs = Set(itemIDs)
        order = itemIDs + order.filter { !reorderedIDs.contains($0) }
        UserDefaults.standard.set(order, forKey: Self.orderKey)
    }

    public func reset() {
        order = []
        hiddenIDs = []
        UserDefaults.standard.removeObject(forKey: Self.orderKey)
        UserDefaults.standard.removeObject(forKey: Self.hiddenKey)
    }
}
