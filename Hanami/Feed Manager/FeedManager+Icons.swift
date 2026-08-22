import Foundation

/// Sync can deliver feeds across several batches, each of which would otherwise
/// queue the same feeds for another refetch while the first is still running.
@MainActor
private var iconRefreshInFlight: Set<Int64> = []

public extension FeedManager {

    /// Synced feeds arrive carrying metadata only, so every device has to
    /// rebuild the icon files itself. Batched so a large library does not open
    /// one connection per feed at once.
    func refreshIcons(for feedsNeedingIcons: [Feed]) async {
        let pending = feedsNeedingIcons.filter { !iconRefreshInFlight.contains($0.id) }
        guard !pending.isEmpty else { return }
        iconRefreshInFlight.formUnion(pending.map(\.id))
        defer { iconRefreshInFlight.subtract(pending.map(\.id)) }
        var index = 0
        while index < pending.count {
            let end = min(index + Self.iconRefreshBatchSize, pending.count)
            await Iconography.shared.refreshAllIcons(for: Array(pending[index..<end]))
            notifyIconChange()
            index = end
        }
    }

    /// Profile icons for cookie-authenticated services are unreachable while
    /// signed out, so a sign-in refetches the ones that failed.
    func connectProviderSessions() {
        ProviderSessionEvents.onSessionEstablished = { [weak self] service in
            Task { @MainActor [weak self] in
                await self?.refreshIcons(forProvider: service)
            }
        }
    }

    func refreshIcons(forProvider service: ProviderSessionEvents.Service) async {
        await refreshIcons(for: feeds.filter { service.matches($0) })
    }

    internal static var iconRefreshBatchSize: Int { 8 }
}
