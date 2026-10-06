import Foundation

extension SuggestedSite {

    var domain: String {
        guard let host = URL(string: feedUrl)?.host() else { return feedUrl }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
