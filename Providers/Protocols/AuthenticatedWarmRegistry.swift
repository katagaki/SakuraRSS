import Foundation

/// Tracks per-conformer warm state for the `Authenticated` default warming.
@MainActor
enum AuthenticatedWarmRegistry {
    private static var warmed: Set<String> = []
    static func isWarmed(_ key: String) -> Bool { warmed.contains(key) }
    static func markWarmed(_ key: String) { warmed.insert(key) }
}
