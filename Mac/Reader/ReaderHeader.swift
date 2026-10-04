import Hanami
import SwiftUI

struct ReaderHeader: View {

    let article: Article
    let feed: Feed?
    let author: String?
    let publishedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.displayTitle)
                .font(.system(size: 26, weight: .bold))
                .textSelection(.enabled)
            HStack(spacing: 6) {
                if let feed {
                    Text(feed.title)
                }
                if let author, !author.isEmpty {
                    Text(verbatim: "·")
                    Text(author)
                }
                if let publishedDate {
                    Text(verbatim: "·")
                    Text(publishedDate, format: .dateTime.day().month().year().hour().minute())
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            Divider()
        }
    }
}
