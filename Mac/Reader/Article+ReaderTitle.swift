import Foundation
import Hanami

extension Article {

    /// Posts already show their text in the body, so the reader titles them
    /// by kind, as iOS does.
    var socialPostReaderTitle: String? {
        if isXPostURL {
            return String(localized: "Article.XPost.Title", table: "Articles")
        }
        if isInstagramPostURL {
            return String(localized: "Article.InstagramPost.Title", table: "Articles")
        }
        if isBlueskyPostURL {
            return String(localized: "Article.BlueskyPost.Title", table: "Articles")
        }
        return nil
    }

    /// Post captions span lines, which the one-line address field shows as blank.
    var locationTitle: String {
        socialPostReaderTitle
            ?? displayTitle.components(separatedBy: .newlines).joined(separator: " ")
    }
}
