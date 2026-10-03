import SwiftUI
import Hanami

/// Lays a list page out beside a reader column, so tapping content opens it
/// on the right instead of pushing over the list.
struct BrowserReaderSplit: ViewModifier {

    let isEnabled: Bool
    @State private var selectedArticle: Article?

    func body(content: Content) -> some View {
        if isEnabled {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    content
                        .frame(width: listColumnWidth(for: geometry.size.width))
                        .environment(\.iPadArticleSelection, $selectedArticle)
                    Divider()
                        .ignoresSafeArea()
                    BrowserReaderColumn(article: selectedArticle)
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            content
        }
    }

    private func listColumnWidth(for availableWidth: CGFloat) -> CGFloat {
        min(420, max(320, availableWidth * 0.36))
    }
}

extension FeedDisplayStyle {
    var usesBrowserReaderSplit: Bool {
        switch self {
        case .inbox, .compact, .timeline, .feed, .feedCompact: true
        default: false
        }
    }
}

extension View {
    func browserReaderSplit(isEnabled: Bool) -> some View {
        modifier(BrowserReaderSplit(isEnabled: isEnabled))
    }
}
