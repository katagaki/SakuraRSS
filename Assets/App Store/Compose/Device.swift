import AppKit

/// `Assets/App Store`, which holds the frames, the raw captures, and the composed output.
let assetsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

/// Captures live in `Raw/<device>/` (or `Raw/<device>/<lang>/` to override one language)
/// and are written to `<device>/<lang>/`.
enum Device: String {
    case iPhone
    case iPad
    case mac = "Mac"

    /// 6.5" iPhone, 13" iPad, and the 16:10 Mac.
    var canvasSize: NSSize {
        switch self {
        case .iPhone: NSSize(width: 1284, height: 2778)
        case .iPad: NSSize(width: 2048, height: 2732)
        case .mac: NSSize(width: 2880, height: 1800)
        }
    }

    /// The top of the header's line box.
    var textTop: CGFloat {
        switch self {
        case .iPhone: 81
        case .iPad: 71
        case .mac: 62
        }
    }

    var textWidth: CGFloat {
        switch self {
        case .iPhone: 1094
        case .iPad: 1858
        case .mac: 2300
        }
    }

    var headerSize: CGFloat {
        switch self {
        case .iPhone: 99
        case .iPad: 109
        case .mac: 124
        }
    }

    var captionSize: CGFloat {
        switch self {
        case .iPhone: 72
        case .iPad: 60
        case .mac: 72
        }
    }

    func rawURL(_ name: String, language: String) -> URL {
        let rawDir = assetsDir.appendingPathComponent("Raw").appendingPathComponent(rawValue)
        let localized = rawDir.appendingPathComponent(language).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: localized.path) { return localized }
        return rawDir.appendingPathComponent(name)
    }

    func outDir(_ language: String) -> URL {
        assetsDir.appendingPathComponent(rawValue).appendingPathComponent(language)
    }
}
