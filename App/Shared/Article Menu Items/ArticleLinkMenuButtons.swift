import Hanami
import SwiftUI
import UIKit

struct ArticleCopyLinkMenuButton: View {

    let article: Article

    var body: some View {
        Button {
            UIPasteboard.general.string = article.url
        } label: {
            Label(String(localized: "Article.CopyLink", table: "Articles"), systemImage: "link")
        }
    }
}

struct ArticleShareMenuButton: View {

    let article: Article

    var body: some View {
        if let shareURL = URL(string: article.url) {
            ShareLink(item: shareURL) {
                Label(
                    String(localized: "Article.Share", table: "Articles"),
                    systemImage: "square.and.arrow.up"
                )
            }
        }
    }
}
