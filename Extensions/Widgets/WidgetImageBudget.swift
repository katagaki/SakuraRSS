import Foundation

/// Widget extensions are hard-killed at roughly 30 MB, and thumbnailing a very
/// large PNG/GIF source can transiently decode near full size, so oversized
/// sources are skipped instead of decoded.
enum WidgetImageBudget {

    static let maxSourceBytes = 4 * 1024 * 1024

    static func isWithinBudget(_ data: Data) -> Bool {
        data.count <= maxSourceBytes
    }

    static func isWithinBudget(byteCount: Int?) -> Bool {
        guard let byteCount else { return false }
        return byteCount <= maxSourceBytes
    }
}
