import SwiftUI
import Hanami

/// The collapsed address field. Tapping it hands over to the omnibox.
struct BrowserAddressCapsule: View {

    @Environment(FeedManager.self) private var feedManager
    let tab: BrowserTab
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(tab, feedManager: feedManager),
                    iconSize: 16,
                    titleFont: .subheadline,
                    showsSubtitle: false
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
