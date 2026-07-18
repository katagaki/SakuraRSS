import SwiftUI

enum ArticleLayout {

    static let readableWidth: CGFloat = 700

    /// The readable-column cap only applies on iPad and Mac; iPhone always
    /// renders article content edge to edge.
    static var capsWidth: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
}

extension View {

    /// Centers a content section within a readable column when the user keeps
    /// the Default width style on iPad/Mac. Full Width and iPhone span edge to
    /// edge.
    func articleColumnWidth(style: ArticleWidthStyle) -> some View {
        let capped = ArticleLayout.capsWidth && style == .default
        return self
            .frame(maxWidth: capped ? ArticleLayout.readableWidth : .infinity)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Caps body media (images, video, embeds) to the readable width on
    /// iPad/Mac so they keep their aspect ratio even when Full Width is set.
    func articleMediaWidthCap() -> some View {
        frame(maxWidth: ArticleLayout.capsWidth ? ArticleLayout.readableWidth : .infinity,
              alignment: .leading)
    }
}
