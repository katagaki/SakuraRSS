import SwiftUI
import Hanami

struct BrowserTabCard: View {

    static let cornerRadius: CGFloat = 16

    /// Portrait, but nowhere near as tall as the screen: at the screen's own
    /// ratio a card runs most of the height of the switcher, and narrowing
    /// the columns to compensate truncates the titles.
    static let previewAspectRatio: CGFloat = 0.75

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private var description: BrowserLocationDescription {
        BrowserLocationDescription.describe(tab, feedManager: feedManager)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                header
                // No padding here: a snapshot bleeds to the card's edges.
                // The stand-in insets itself instead.
                // The ratio is driven off a flexible shape rather than the
                // preview: a stand-in has no intrinsic size, so aspectRatio
                // would collapse it to its content.
                Color.clear
                    .aspectRatio(BrowserTabCard.previewAspectRatio, contentMode: .fit)
                    .overlay(alignment: .top) {
                        BrowserTabPreview(tab: tab)
                    }
                    .clipped()
            }
            .background(.background.secondary, in: .rect(cornerRadius: BrowserTabCard.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BrowserTabCard.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            }
            .contentShape(.rect(cornerRadius: BrowserTabCard.cornerRadius))
            .reportsTabCardFrame(id: tab.id, to: store)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: 6) {
            BrowserLocationLabel(
                description: description,
                iconSize: 16,
                titleFont: .caption.weight(.medium),
                showsSubtitle: false
            )
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Menu.CloseTab", table: "Browser"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
