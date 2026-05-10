import Foundation

/// Tracks per-conformer warm state for the `Authenticated` default warming.
@MainActor
public enum AuthenticatedWarmRegistry {
    private static var warmed: Set<String> = []
    public static func isWarmed(_ key: String) -> Bool { warmed.contains(key) }
    public static func markWarmed(_ key: String) { warmed.insert(key) }
}
