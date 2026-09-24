import SwiftUI
import Hanami

struct BrowserTabCard: View {

    static let cornerRadius: CGFloat = 16

    /// Portrait, but far shorter than the screen: at the screen's ratio a card
    /// runs most of the height of the switcher.
    static let previewAspectRatio: CGFloat = 0.75

    static let closeDistance: CGFloat = 90

    /// How far the selection ring sits outside the card's edge.
    static let selectionRingInset: CGFloat = 3

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isPastCloseDistance = false

    private var description: BrowserLocationDescription {
        BrowserLocationDescription.describe(tab, feedManager: feedManager)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                header
                // Ratio driven off a flexible shape, not the preview: a
                // stand-in has no intrinsic size for aspectRatio to work from.
                Color.clear
                    .aspectRatio(BrowserTabCard.previewAspectRatio, contentMode: .fit)
                    .overlay(alignment: .top) {
                        BrowserTabPreview(tab: tab)
                    }
            }
            .background(.background.secondary)
            // Clipped as a whole: `clipped()` on the preview trims to the
            // card's bounds but not to its rounded corners.
            .clipShape(.rect(cornerRadius: BrowserTabCard.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
            // Outside the card, not over it: the collapsing page lands on the
            // card's own bounds, so an inset border spends the transition
            // hidden under the page and snaps back the frame it is swapped out.
            .background {
                RoundedRectangle(
                    cornerRadius: BrowserTabCard.cornerRadius + BrowserTabCard.selectionRingInset,
                    style: .continuous
                )
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                .padding(-BrowserTabCard.selectionRingInset)
            }
            .contentShape(.rect(cornerRadius: BrowserTabCard.cornerRadius))
            .reportsTabCardFrame(id: tab.id, to: store)
        }
        .offset(x: dragOffset)
        .opacity(closeProgress)
        // High priority: the card is a button, which otherwise swallows the drag.
        .highPriorityGesture(closeDragGesture)
        .buttonStyle(.plain)
    }

    /// Fades the card as it is pushed away, so the swipe reads as closing.
    private var closeProgress: Double {
        1 - min(1, Double(-dragOffset / BrowserTabCard.closeDistance))
    }

    private var closeDragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                // Vertical drags belong to the grid's scroll view.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = min(0, value.translation.width)
                // Tapped on crossing either way, so the release point is felt.
                let isPast = store.canCloseTabs && -dragOffset > BrowserTabCard.closeDistance
                if isPast != isPastCloseDistance {
                    isPastCloseDistance = isPast
                    Haptics.impact(.light)
                }
            }
            .onEnded { value in
                isPastCloseDistance = false
                if store.canCloseTabs, value.translation.width < -BrowserTabCard.closeDistance {
                    withAnimation(.smooth(duration: 0.2)) {
                        dragOffset = -BrowserTabCard.closeDistance * 2
                    }
                    onClose()
                } else {
                    withAnimation(.smooth(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
            }
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
            if store.canCloseTabs {
                closeButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var closeButton: some View {
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
}

/// Compared on what the card draws, not its actions: the switcher hands in new
/// closures every pass, so every card would redraw whenever any tab changed.
/// The actions only ever act on this card's own tab.
extension BrowserTabCard: Equatable {
    static func == (lhs: BrowserTabCard, rhs: BrowserTabCard) -> Bool {
        lhs.tab.id == rhs.tab.id
            && lhs.tab.location == rhs.tab.location
            && lhs.tab.pageIdentity == rhs.tab.pageIdentity
            && lhs.isSelected == rhs.isSelected
    }
}
