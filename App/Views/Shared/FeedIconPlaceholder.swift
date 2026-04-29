import SwiftUI

/// Placeholder tile used when an article has no cover image; centers the feed icon.
struct FeedIconPlaceholder: View {

    enum Fallback {
        case initials
        case symbol(String)
    }

    @Environment(\.colorScheme) private var colorScheme

    let favicon: UIImage?
    let acronymIcon: UIImage?
    let feedName: String?
    let isSocialFeed: Bool
    let iconSize: CGFloat
    var cornerRadius: CGFloat = 0
    var fallback: Fallback = .initials

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))

        ZStack {
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius).fill(bgColor)
            } else {
                Rectangle().fill(bgColor)
            }
            iconView
                .frame(width: iconSize, height: iconSize)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let favicon {
            if isSocialFeed {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else if let acronymIcon {
            Image(uiImage: acronymIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackView
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        switch fallback {
        case .initials:
            if let feedName, let letter = feedName.first {
                Text(String(letter).uppercased())
                    .font(.system(size: iconSize * 0.6, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: iconSize * 0.75, weight: .light))
                .foregroundStyle(.tertiary)
        }
    }
}
