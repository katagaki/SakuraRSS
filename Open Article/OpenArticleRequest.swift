import Foundation

/// Local copy of the request struct used to launch the host app via the
/// `sakura://open` URL scheme. The main app declares its own copy in
/// `Feeds/OpenArticleRequest.swift`; both must stay in sync.
struct OpenArticleRequest: Equatable, Sendable {

    enum Mode: String, CaseIterable, Sendable {
        case viewer
        case clearThisPage = "clearthispage"
        case readability
        case archiveToday = "archive.today"
    }

    enum TextMode: String, CaseIterable, Sendable {
        case auto
        case fetch
        case extract
    }

    var url: String
    var mode: Mode
    var textMode: TextMode

    init(url: String, mode: Mode, textMode: TextMode = .auto) {
        self.url = url
        self.mode = mode
        self.textMode = textMode
    }

    func makeURL() -> URL? {
        var components = URLComponents()
        components.scheme = "sakura"
        components.host = "open"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "mode", value: mode.rawValue),
            URLQueryItem(name: "url", value: url)
        ]
        if mode == .viewer {
            items.append(URLQueryItem(name: "textMode", value: textMode.rawValue))
        }
        components.queryItems = items
        return components.url
    }
}
