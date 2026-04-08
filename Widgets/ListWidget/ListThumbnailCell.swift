import SwiftUI
import WidgetKit

struct ListThumbnailCell: View {

    let article: ListWidgetArticle
    let listTitle: String

    var body: some View {
        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    if let imageData = article.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .renderingMode(.original)
                            .resizable()
                            .widgetAccentedRenderingMode(.fullColor)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color("AccentColor").opacity(0.3))
                            .overlay {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(article.title)
                    .font(.system(size: 12, weight: .semibold, design: .default).width(.condensed))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 6)
                    .padding(.horizontal, 2)
            }
        }
    }
}
