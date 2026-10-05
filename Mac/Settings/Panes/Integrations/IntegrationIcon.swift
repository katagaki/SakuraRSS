import Hanami
import SwiftUI

struct IntegrationIcon: View {

    let integration: Integration
    let size: CGFloat
    @State private var appIcon: NSImage?

    var body: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFill()
            } else {
                // Scaled to fit rather than set as a font, which places the
                // glyph by its baseline and leaves it off centre.
                Image(systemName: integration.fallbackSymbolName)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(size * 0.22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .task(id: integration) {
            // The header reuses this view for each integration, so the last
            // one's app icon has to go before a symbol can show.
            appIcon = nil
            guard let section = integration.feedSection else { return }
            appIcon = await Iconography.shared.icon(for: section)
        }
    }
}
