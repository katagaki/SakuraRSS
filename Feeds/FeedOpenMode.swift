import Foundation

nonisolated enum FeedOpenMode: String, CaseIterable, Sendable {
    case inAppViewer
    case browser
    case inAppBrowser
    case inAppBrowserReader
    case clearThisPage
    case readability
    case archivePh
}
