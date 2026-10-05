import Hanami
import SwiftUI

/// Columns filled in turn, so items of differing heights stack without gaps.
struct ContentMasonryGrid<Item: View>: View {

    let articles: [Article]
    @ViewBuilder let item: (Article) -> Item
    @State private var columnCount = 3

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(0..<columnCount, id: \.self) { column in
                LazyVStack(spacing: 18) {
                    ForEach(articles(inColumn: column)) { article in
                        item(article)
                    }
                }
            }
        }
        .onGeometryChange(for: Int.self) { proxy in
            max(1, Int(proxy.size.width / 260))
        } action: { count in
            columnCount = count
        }
    }

    private func articles(inColumn column: Int) -> [Article] {
        articles.enumerated()
            .filter { $0.offset % columnCount == column }
            .map(\.element)
    }
}
