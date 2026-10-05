import Hanami

extension FeedSection {
    var browserSymbolName: String {
        switch self {
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram: "photo.on.rectangle"
        case .bluesky, .fediverse, .note, .reddit, .x: "person.2"
        case .substack: "envelope"
        case .vimeo, .youtube, .niconico: "play.rectangle"
        }
    }
}
