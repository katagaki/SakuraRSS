import Foundation

/// What the visible page calls itself. Pages report this upward because a
/// `NavigationPath` is opaque once pushed into, so the store cannot read the
/// stack back to label it.
public protocol TabPageIdentity: Equatable, Codable {
    associatedtype PathToken: Hashable, Codable

    /// How to push this page again after a relaunch. Nil for a tab's root,
    /// which is restored from the root itself.
    var pathToken: PathToken? { get }

    /// Whether two reports are the same page. A page on its way out
    /// re-reports itself as the stack pops, by which point its path token has
    /// already unwound to the root's, so conformers should fall back to
    /// comparing names when either token is missing.
    func names(_ other: Self) -> Bool
}
