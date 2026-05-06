import SwiftUI

struct ListArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList

    @State private var hasScrolledPastTitle: Bool = false
    @State private var effectiveDisplayStyle: FeedDisplayStyle?
    @State private var scrollToTopTick: Int = 0

    private var currentList: FeedList {
        feedManager.lists.first(where: { $0.id == list.id }) ?? list
    }

    private var styleSupportsRichHeader: Bool {
        effectiveDisplayStyle?.supportsRichHeader ?? true
    }

    private var showsPrincipalTitle: Bool {
        !styleSupportsRichHeader || hasScrolledPastTitle
    }

    var body: some View {
        HomeSectionView(
            list: currentList,
            showsListHeader: true,
            effectiveStyleBinding: $effectiveDisplayStyle,
            externalScrollToTopTrigger: scrollToTopTick
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                #if os(visionOS)
                Text(currentList.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 42)
                    .contentShape(.rect)
                    .onTapGesture {
                        scrollToTopTick &+= 1
                    }
                    .allowsHitTesting(showsPrincipalTitle)
                    .opacity(showsPrincipalTitle ? 1 : 0)
                    .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
                #else
                Text(currentList.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 42)
                    .padding(.horizontal, 18)
                    .compatibleGlassEffect(in: .capsule, interactive: true)
                    .contentShape(.capsule)
                    .onTapGesture {
                        scrollToTopTick &+= 1
                    }
                    .allowsHitTesting(showsPrincipalTitle)
                    .opacity(showsPrincipalTitle ? 1 : 0)
                    .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
                #endif
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y > 90
        } action: { _, scrolled in
            guard scrolled != hasScrolledPastTitle else { return }
            withAnimation(.smooth.speed(2.0)) {
                hasScrolledPastTitle = scrolled
            }
        }
        .animation(.smooth.speed(2.0), value: styleSupportsRichHeader)
    }
}
