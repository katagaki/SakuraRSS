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
                Image(systemName: integration == .webFeeds ? "wand.and.stars" : "app.dashed")
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .task(id: integration) {
            guard let section = integration.feedSection else { return }
            appIcon = await Iconography.shared.icon(for: section)
        }
    }
}
