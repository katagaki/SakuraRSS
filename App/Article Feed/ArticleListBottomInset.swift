import SwiftUI

private struct ArticleListBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Extra bottom inset applied to article scroll content so the last rows and
    /// the load-more control clear the floating Mark All Read pill overlaid at the
    /// bottom of home sections. Zero where no bottom overlay is present.
    var articleListBottomInset: CGFloat {
        get { self[ArticleListBottomInsetKey.self] }
        set { self[ArticleListBottomInsetKey.self] = newValue }
    }
}
