import Foundation
import Observation

/// Items missing from the saved order (new lists, newly followed feed
/// types) land after the ordered ones, in the order they were offered.
@MainActor
@Observable
public final class TodayQuickAccessPreferences {

    public static let shared = TodayQuickAccessPreferences()

    private var settings: TodayQuickAccessSettings

    public var isCustomized: Bool {
        settings != .empty
    }

    private init() {
        settings = (try? DatabaseManager.shared.todayQuickAccessSettings()) ?? .empty
    }

    /// Picks up settings from a database restored from an iCloud backup.
    public func reload() {
        settings = (try? DatabaseManager.shared.todayQuickAccessSettings()) ?? .empty
    }

    public func ordered(_ items: [TodayQuickAccessItem]) -> [TodayQuickAccessItem] {
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

    public func visible(_ items: [TodayQuickAccessItem]) -> [TodayQuickAccessItem] {
        ordered(items).filter { !settings.hiddenIDs.contains($0.id) }
    }

    public func isHidden(_ item: TodayQuickAccessItem) -> Bool {
        settings.hiddenIDs.contains(item.id)
    }

    public func setHidden(_ isHidden: Bool, for item: TodayQuickAccessItem) {
        if isHidden {
            settings.hiddenIDs.insert(item.id)
        } else {
            settings.hiddenIDs.remove(item.id)
        }
        save()
    }

    /// Keeps saved positions for items not in `items` (such as ones a
    /// Focus is filtering out) so they don't drop to the end when they return.
    public func saveOrder(_ items: [TodayQuickAccessItem]) {
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
        try? DatabaseManager.shared.saveTodayQuickAccessSettings(settings)
    }
}
