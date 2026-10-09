import SwiftUI
import Hanami

extension FeedArticlesView {

    @ToolbarContentBuilder
    var principalTitleItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            #if os(visionOS)
            principalTitleContent
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 42)
                .contentShape(.rect)
                .onTapGesture { scrollToTopTick &+= 1 }
                .allowsHitTesting(showsPrincipalTitle)
                .opacity(showsPrincipalTitle ? 1 : 0)
                .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
            #else
            principalTitleContent
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 44)
                .padding(.horizontal, 18)
                .compatibleGlassEffect(in: .capsule, interactive: true)
                .contentShape(.capsule)
                .onTapGesture { scrollToTopTick &+= 1 }
                .allowsHitTesting(showsPrincipalTitle)
                .opacity(showsPrincipalTitle ? 1 : 0)
                .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
            #endif
        }
    }

    var styleSupportsRichHeader: Bool {
        effectiveDisplayStyle?.supportsRichHeader ?? true
    }

    var showsPrincipalTitle: Bool {
        !isBrowserChromeActive && (!styleSupportsRichHeader || hasScrolledPastTitle)
    }

    @ViewBuilder
    var principalTitleContent: some View {
        if scopedRefreshState.isStopping {
            Text(String(localized: "Refresh.Stopping", table: "Home"))
                .font(.subheadline)
                .fontWeight(.semibold)
        } else {
            #if os(visionOS)
            VStack(alignment: .leading, spacing: 0) {
                feedTitleAndDomain
            }
            #else
            VStack(spacing: 0) {
                feedTitleAndDomain
            }
            #endif
        }
    }

    @ViewBuilder
    var feedTitleAndDomain: some View {
        Text(currentFeed.title)
            .font(.subheadline)
            .fontWeight(.semibold)
        if !currentFeed.domain.isEmpty {
            Text(currentFeed.domain)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
