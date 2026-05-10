import Foundation
import Hanami

nonisolated enum YouTubeOpenMode: String, CaseIterable, Sendable {
    case inAppPlayer
    case youTubeApp
    case browser
}
