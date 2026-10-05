import Foundation

enum WhatsNewRelease {

    static let version = "2.0"
    static let lastShownVersionKey = "WhatsNew.LastShownVersion"

    static func isUnseen(lastShownVersion: String) -> Bool {
        lastShownVersion.isEmpty
            || lastShownVersion.compare(version, options: .numeric) == .orderedAscending
    }
}
