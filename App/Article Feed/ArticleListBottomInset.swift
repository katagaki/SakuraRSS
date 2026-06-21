import SwiftUI

private struct ArticleListBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var articleListBottomInset: CGFloat {
        get { self[ArticleListBottomInsetKey.self] }
        set { self[ArticleListBottomInsetKey.self] = newValue }
    }
}
