import Foundation

/// Third-party embed providers that the article extractor recognizes and
/// promotes into inline `{{EMBED}}provider|url{{/EMBED}}` markers.
nonisolated enum EmbedProvider: String, CaseIterable {
    case vimeo
    case tiktok
    case instagram
    case bluesky
    case spotify
    case soundcloud
    case codepen
    case gist

    /// Human-readable display name used in the fallback link card.
    var displayName: String {
        switch self {
        case .vimeo: return "Vimeo"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .bluesky: return "Bluesky"
        case .spotify: return "Spotify"
        case .soundcloud: return "SoundCloud"
        case .codepen: return "CodePen"
        case .gist: return "GitHub Gist"
        }
    }

    /// SF Symbols name for the fallback link card.
    var symbolName: String {
        switch self {
        case .vimeo, .tiktok: return "play.rectangle.fill"
        case .instagram, .bluesky: return "bubble.left.and.bubble.right.fill"
        case .spotify, .soundcloud: return "music.note"
        case .codepen, .gist: return "curlybraces"
        }
    }

    init?(markerValue: String) {
        self.init(rawValue: markerValue.lowercased())
    }
}
