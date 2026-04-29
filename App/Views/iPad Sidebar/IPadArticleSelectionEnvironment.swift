import SwiftUI

struct IPadArticleSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<Article?>? = nil
}

extension EnvironmentValues {
    var iPadArticleSelection: Binding<Article?>? {
        get { self[IPadArticleSelectionKey.self] }
        set { self[IPadArticleSelectionKey.self] = newValue }
    }
}
