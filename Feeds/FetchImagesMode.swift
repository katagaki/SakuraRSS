import Foundation

/// Controls whether article images should be prefetched during feed
/// refreshes, and whether the work is restricted to non-expensive
/// (typically Wi-Fi) network paths.
nonisolated enum FetchImagesMode: String, CaseIterable, Sendable {
    case always
    case wifiOnly
    case off
}
