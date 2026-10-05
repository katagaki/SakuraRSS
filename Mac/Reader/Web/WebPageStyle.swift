import Foundation
import Hanami

/// The ways the Mac shows content as a web page rather than in its reader.
enum WebPageStyle {
    case page
    case readerMode
    case clearThisPage
    case archive

    /// Nil for the reader, which isn't a web page.
    init?(mode: FeedOpenMode) {
        switch mode {
        case .inAppViewer: return nil
        case .browser, .inAppBrowser: self = .page
        case .inAppBrowserReader, .readability: self = .readerMode
        case .clearThisPage: self = .clearThisPage
        case .archivePh: self = .archive
        }
    }

    func address(for url: URL) -> URL? {
        switch self {
        case .page, .readerMode: url
        case .clearThisPage: ClearThisPageAddress.url(for: url)
        case .archive: ArchivePhAddress.url(for: url)
        }
    }

    var userScripts: [String] {
        switch self {
        case .page, .archive: []
        case .readerMode: [ReadabilityScript.bundledLibrary]
        case .clearThisPage: [ClearThisPageAddress.themeScript]
        }
    }

    /// Reading services get a throwaway store, as on iOS; plain pages keep the
    /// user's sign-ins.
    var usesPersistentData: Bool {
        self == .page
    }
}
