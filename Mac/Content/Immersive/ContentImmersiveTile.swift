import Hanami
import SwiftUI

/// A Cards or Scroll item, drawn at a phone's portrait proportions the way
/// iOS fills the screen with them.
struct ContentImmersiveTile: View {

    static let cardAspectRatio: CGFloat = 9 / 16
    static let pageAspectRatio: CGFloat = 9 / 19.5

    let article: Article
    let feed: Feed?
    let isRead: Bool
    let style: FeedDisplayStyle

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                background(size: geometry.size)
                LinearGradient(
                    colors: [.black.opacity(0.85), .black.opacity(0)],
                    startPoint: .bottom,
                    endPoint: .center
                )
                caption
                    .padding(style == .cards ? 24 : 20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .contentShape(.rect(cornerRadius: cornerRadius))
    }

    private var cornerRadius: CGFloat {
        style == .cards ? 24 : 32
    }

    private func background(size: CGSize) -> some View {
        Rectangle()
            .fill(.quinary)
            .overlay {
                if let feed {
                    FeedIconView(feed: feed, size: size.width * 0.4)
                        .opacity(0.5)
                        .offset(y: -size.height * 0.1)
                }
            }
            .overlay {
                if let urlString = article.imageURL, let url = URL(string: urlString) {
                    CachedImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: style == .cards ? 8 : 10) {
            if let feed {
                HStack(spacing: 6) {
                    FeedIconView(feed: feed, size: 20)
                    Text(feed.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                    if !isRead {
                        Circle()
                            .fill(.tint)
                            .frame(width: 7, height: 7)
                    }
                }
            }
            Text(article.displayTitle)
                .font(style == .cards ? .system(.title, weight: .bold).width(.condensed) : .body.weight(.bold))
                .lineLimit(style == .cards ? 4 : 3)
            if article.hasMeaningfulSummary, let summary = article.summary {
                Text(SummaryPreview.text(for: summary))
                    .font(style == .cards ? .subheadline : .body)
                    .opacity(0.9)
                    .lineLimit(style == .cards ? 2 : 5)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
