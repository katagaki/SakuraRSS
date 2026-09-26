import SwiftUI
import Hanami

/// Icon plus title used wherever a location is named: the address capsule, tab
/// cards and the omnibox suggestion rows.
struct BrowserLocationLabel: View {

    /// Navigating swaps the icon, the title and often the subtitle line all at
    /// once. Without this the bar rewrites itself in a single frame.
    static let contentChange: Animation = .smooth(duration: 0.25)

    let description: BrowserLocationDescription
    var iconSize: CGFloat = 18
    var titleFont: Font = .subheadline
    var subtitleFont: Font = .caption2
    var showsSubtitle: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            icon
                .id(iconIdentity)
                .transition(.opacity)
            VStack(alignment: .leading, spacing: 1) {
                Text(description.title)
                    .font(titleFont)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                if showsSubtitle, let subtitle = description.subtitle {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .transition(.opacity)
                }
            }
        }
        .animation(BrowserLocationLabel.contentChange, value: description)
    }

    /// A feed icon and a symbol are different views, so the swap has to be a
    /// replacement to cross-fade rather than a redraw in place.
    private var iconIdentity: String {
        if let feed = description.feed {
            "feed-\(feed.id)"
        } else {
            "symbol-\(description.symbolName)"
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let feed = description.feed {
            FeedIcon(
                feed: feed,
                size: iconSize,
                cornerRadius: BrowserIconMetrics.cornerRadius(for: iconSize)
            )
        } else {
            Image(systemName: description.symbolName)
                .font(.system(size: iconSize * 0.75))
                .foregroundStyle(.secondary)
                .frame(width: iconSize, height: iconSize)
        }
    }
}
