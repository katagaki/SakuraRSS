import Foundation
import SwiftSoup

struct AppleAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["apple.com"])
    }

    var requiresWebView: Bool { true }

    func extract(
        document _: Document,
        baseURL _: URL,
        excludeTitle _: String?
    ) -> ExtractionResult? {
        nil
    }
}
