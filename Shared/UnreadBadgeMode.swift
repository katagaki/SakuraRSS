import Foundation
import Hanami

nonisolated enum UnreadBadgeMode: String, CaseIterable, Sendable {
    case homeScreenAndHomeTab
    case homeScreenOnly
    case homeTabOnly
    case none
}
