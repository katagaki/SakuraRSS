import Foundation

/// Navigation destination wrapping an ephemeral article (one created from
/// `sakura://open`) with the viewer mode and text mode picked by the user.
struct EphemeralArticleDestination: Hashable {
    let article: Article
    let mode: OpenArticleRequest.Mode
    let textMode: OpenArticleRequest.TextMode
}
