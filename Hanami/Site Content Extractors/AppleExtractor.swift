import Foundation
import SwiftSoup

public struct AppleExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["apple.com"])
    }

    public var requiresWebView: Bool { true }

    public func extract(
        document _: Document,
        baseURL _: URL,
        excludeTitle _: String?
    ) -> ExtractionResult? {
        nil
    }
}
