import SwiftUI
import Hanami

struct FeedSectionIcon: View {
    let section: FeedSection
    let symbolName: String
    let size: CGFloat
    @State private var icon: UIImage?

    var body: some View {
        Group {
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: BrowserIconMetrics.cornerRadius(for: size)))
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.75))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: section) {
            icon = nil
            icon = await Iconography.shared.icon(for: section)
        }
    }
}
