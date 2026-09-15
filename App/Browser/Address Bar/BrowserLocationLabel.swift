import SwiftUI
import Hanami

/// Icon plus title used wherever a location is named: the address capsule, tab
/// cards and the omnibox suggestion rows.
struct BrowserLocationLabel: View {

    let description: BrowserLocationDescription
    var iconSize: CGFloat = 18
    var titleFont: Font = .subheadline
    var subtitleFont: Font = .caption2
    var showsSubtitle: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(description.title)
                    .font(titleFont)
                    .lineLimit(1)
                if showsSubtitle, let subtitle = description.subtitle {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let feed = description.feed {
            FeedIcon(feed: feed, size: iconSize, cornerRadius: iconSize / 4.5)
        } else {
            Image(systemName: description.symbolName)
                .font(.system(size: iconSize * 0.75))
                .foregroundStyle(.secondary)
                .frame(width: iconSize, height: iconSize)
        }
    }
}
