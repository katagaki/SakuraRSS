import SwiftUI

struct SingleFeedSmallView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if let article = entry.articles.first {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    if let imageData = article.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .renderingMode(.original)
                            .resizable()
                            .widgetAccentedRenderingMode(.fullColor)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color("AccentColor").opacity(0.3))
                            .overlay {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.system(size: 12, weight: .semibold, design: .default).width(.condensed))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(entry.feedTitle)
                        .font(.system(size: 10, weight: .medium, design: .default).width(.condensed))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.horizontal, 2)
            }
            .widgetURL(URL(string: "sakura://article/\(article.id)")!)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "newspaper")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text("Widget.NoArticles")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
