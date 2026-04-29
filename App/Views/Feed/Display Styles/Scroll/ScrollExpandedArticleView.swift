import SwiftUI

struct ScrollExpandedArticleView: View {
    @Environment(FeedManager.self) var feedManager
    let article: Article
    let feedName: String?
    let favicon: UIImage?
    let acronymIcon: UIImage?
    let isVideoFeed: Bool
    let contextInsets: EdgeInsets
    let headerNamespace: Namespace.ID
    let onTapToCollapse: () -> Void
    let onAdvance: () -> Void

    @State var extractedText: String?
    @State var isExtracting = true
    @State var isPaywalled = false
    @State var extractedAuthor: String?
    @State var extractedPublishedDate: Date?
    @State var extractedLeadImageURL: String?
    @State var extractedPageTitle: String?
    @State private var scrollOffset: CGFloat = 0
    @State private var maxScrollOffset: CGFloat = 0
    @State private var imageViewerURL: URL?
    @Namespace private var imageViewerNamespace
    private static let overscrollThreshold: CGFloat = 80

    var displayText: String? {
        extractedText ?? article.summary
    }

    private var displayTitle: String {
        article.title
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                if isExtracting && extractedText == nil {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if let text = displayText {
                    ContentBlockStack(
                        text: text,
                        textStyle: .white,
                        imageNamespace: imageViewerNamespace,
                        onImageTap: { url in imageViewerURL = url }
                    )
                    .transition(.blurReplace)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20 + contextInsets.top)
            .padding(.bottom, 40 + contextInsets.bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width > 40 &&
                                abs(value.translation.height) < 60 {
                                onTapToCollapse()
                            }
                        }
                )
        }
        .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
            ScrollMetrics(
                offset: geo.contentOffset.y,
                maxOffset: max(0, geo.contentSize.height - geo.containerSize.height)
            )
        } action: { _, new in
            scrollOffset = new.offset
            maxScrollOffset = new.maxOffset
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .decelerating || newPhase == .idle else { return }
            if scrollOffset < -Self.overscrollThreshold {
                onTapToCollapse()
            } else if scrollOffset > maxScrollOffset + Self.overscrollThreshold {
                onAdvance()
            }
        }
        .navigationDestination(item: $imageViewerURL) { url in
            ImageViewerView(url: url)
                .navigationTransition(.zoom(sourceID: url, in: imageViewerNamespace))
        }
        .task {
            await extractArticleContent()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Group {
                    if let favicon {
                        FaviconImage(favicon, size: 24, cornerRadius: 4, circle: isVideoFeed)
                    } else if let acronymIcon {
                        FaviconImage(acronymIcon, size: 24, cornerRadius: 4,
                                     circle: isVideoFeed, skipInset: true)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 24, circle: isVideoFeed, cornerRadius: 4)
                    }
                }
                .matchedGeometryEffect(id: "headerIcon", in: headerNamespace)
                if let feedName {
                    Text(feedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "headerFeedName", in: headerNamespace)
                }
            }

            Text(displayTitle)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.white)
                .matchedGeometryEffect(id: "headerTitle", in: headerNamespace)

            HStack(spacing: 8) {
                if let author = article.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                if article.author != nil, article.publishedDate != nil {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.55))
                }
                if let date = article.publishedDate {
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Divider()
                .overlay(.white.opacity(0.2))
        }
    }

}

extension ScrollExpandedArticleView: ExtractsArticle {}
