import SwiftUI
import Hanami

struct BrowserTabCard: View {

    static let cornerRadius: CGFloat = 16

    @Environment(FeedManager.self) private var feedManager
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
                BrowserTabPreview(tab: tab)
                    .padding(12)
                    .frame(height: 132)
                    .clipped()
            }
            .background(.background.secondary, in: .rect(cornerRadius: BrowserTabCard.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BrowserTabCard.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            }
            .contentShape(.rect(cornerRadius: BrowserTabCard.cornerRadius))
            .reportsTabCardFrame(id: tab.id)
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
