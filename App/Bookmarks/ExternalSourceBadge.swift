import SwiftUI

/// Corner marker shown on bookmarks saved into the app from another app via
/// the share extension.
struct ExternalSourceBadge: View {

    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "globe")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.accentColor, in: .circle)
            .overlay {
                Circle().strokeBorder(.background, lineWidth: 1.5)
            }
            .accessibilityLabel(Text(String(localized: "Bookmarks.ExternalSource", table: "Articles")))
    }
}
