import Foundation

public nonisolated extension ContentBlock {

    /// Fills the parse cache ahead of the first render, which otherwise parses
    /// a long article on the main thread inside the view body.
    @concurrent
    static func prepareIdentifiedBlocks(offMainActorFrom text: String) async {
        _ = cachedIdentifiedBlocks(text)
    }
}
