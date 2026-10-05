import Foundation
import Hanami
import Observation

/// Context menu items live outside the presenting view's hierarchy, so the
/// sheet is driven through the environment instead of local state.
@MainActor
@Observable
final class BookmarkDetailPresenter {
    var article: Article?
}
