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
                    ForEach(articles.indices.filter { $0 % columnCount == column }, id: \.self) { index in
                        item(articles[index])
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
}
