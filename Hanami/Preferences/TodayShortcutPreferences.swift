import Foundation
import Observation

/// Shortcuts missing from the saved order (new lists, newly followed feed
/// types) land after the ordered ones, in the order they were offered.
@MainActor
@Observable
public final class TodayShortcutPreferences {

    public static let shared = TodayShortcutPreferences()

    private var settings: TodayShortcutSettings

    public var isCustomized: Bool {
        settings != .empty
    }

    private init() {
        settings = (try? DatabaseManager.shared.todayShortcutSettings()) ?? .empty
    }

    /// Picks up settings from a database restored from an iCloud backup.
    public func reload() {
        settings = (try? DatabaseManager.shared.todayShortcutSettings()) ?? .empty
    }

    public func ordered(_ items: [TodayShortcutItem]) -> [TodayShortcutItem] {
        let positions = Dictionary(
            settings.order.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let savedItems = items
            .filter { positions[$0.id] != nil }
            .sorted { positions[$0.id, default: .max] < positions[$1.id, default: .max] }
        let unsavedItems = items.filter { positions[$0.id] == nil }
        return savedItems + unsavedItems
    }

    public func visible(_ items: [TodayShortcutItem]) -> [TodayShortcutItem] {
        ordered(items).filter { !settings.hiddenIDs.contains($0.id) }
    }

    public func isHidden(_ item: TodayShortcutItem) -> Bool {
        settings.hiddenIDs.contains(item.id)
    }

    public func setHidden(_ isHidden: Bool, for item: TodayShortcutItem) {
        if isHidden {
            settings.hiddenIDs.insert(item.id)
        } else {
            settings.hiddenIDs.remove(item.id)
        }
        save()
    }

    /// Keeps saved positions for shortcuts not in `items` (such as ones a
    /// Focus is filtering out) so they don't drop to the end when they return.
    public func saveOrder(_ items: [TodayShortcutItem]) {
        let itemIDs = items.map(\.id)
        let reorderedIDs = Set(itemIDs)
        settings.order = itemIDs + settings.order.filter { !reorderedIDs.contains($0) }
        save()
    }

    public func reset() {
        settings = .empty
        save()
    }

    private func save() {
        try? DatabaseManager.shared.saveTodayShortcutSettings(settings)
    }
}
