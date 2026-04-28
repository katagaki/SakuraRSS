import Foundation

/// Encodes a request to open an arbitrary web page in one of Sakura's viewers,
/// triggered by the Open Article extension and parsed by the main app.
///
/// URL form:
/// `sakura://open?mode=<viewer|clearthispage|readability|archive.today>&textMode=<auto|fetch|extract>&url=<url>`
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
    /// Only meaningful when `mode == .viewer`.
    var textMode: TextMode

    init(url: String, mode: Mode, textMode: TextMode = .auto) {
        self.url = url
        self.mode = mode
        self.textMode = textMode
    }

    /// Parses `sakura://open?mode=...&textMode=...&url=...` into a request.
    init?(url: URL) {
        guard url.scheme == "sakura", url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return nil
        }
        var modeString: String?
        var textModeString: String?
        var targetURLString: String?
        for item in items {
            switch item.name {
            case "mode": modeString = item.value
            case "textMode": textModeString = item.value
            case "url": targetURLString = item.value
            default: break
            }
        }
        guard let targetURLString, !targetURLString.isEmpty,
              let mode = modeString.flatMap(Mode.init(rawValue:)) else {
            return nil
        }
        self.url = targetURLString
        self.mode = mode
        self.textMode = textModeString.flatMap(TextMode.init(rawValue:)) ?? .auto
    }

    /// Builds the launch URL for the host app.
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
