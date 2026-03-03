import SwiftUI
@preconcurrency import Translation

extension ArticleDetailView {
    func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }
}
