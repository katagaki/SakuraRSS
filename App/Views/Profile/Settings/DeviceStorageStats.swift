import Foundation

nonisolated struct DeviceStorageStats: Sendable {
    let totalCapacity: Int64
    let availableCapacity: Int64
    let breakdown: SakuraStorageBreakdown

    var sakuraBytes: Int64 { breakdown.totalBytes }

    var usedByOtherApps: Int64 {
        max(0, totalCapacity - availableCapacity - sakuraBytes)
    }

    static func current(breakdown: SakuraStorageBreakdown) -> DeviceStorageStats {
        let url = URL(fileURLWithPath: NSHomeDirectory() as String)
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let available = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return DeviceStorageStats(
            totalCapacity: total,
            availableCapacity: available,
            breakdown: breakdown
        )
    }
}
