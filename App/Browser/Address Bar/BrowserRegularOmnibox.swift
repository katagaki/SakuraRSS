import EnhancedNavigation
import SwiftUI
import Hanami

/// The visionOS shell's address field. iPad and Mac get the same field and
/// popup through EnhancedNavigation's top bar instead.
struct BrowserRegularOmnibox: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserPageSlots.self) private var slots
    @Environment(BrowserFavourites.self) private var favourites
    @Environment(BrowserOmniboxModel.self) private var omnibox
    @Environment(\.browserOmniboxAction) private var openOmnibox

    let popupMaxHeight: CGFloat

    var body: some View {
        Group {
            if omnibox.isActive {
                BrowserOmniboxEditingField()
                    .onKeyPress(.escape) {
                        withAnimation(BrowserOmniboxModel.transition) { omnibox.deactivate() }
                        return .handled
                    }
            } else {
                BrowserAddressCapsule(
                    tab: store.selectedTab,
                    progress: slots.displayedProgress(for: store.selectedTabID, in: store)
                ) {
                    openOmnibox?()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
        .frame(maxWidth: 560)
        .compatibleGlassEffect(in: .capsule, interactive: true)
        .contextMenu {
            if !omnibox.isActive {
                BrowserPageMenu(store: store, favourites: favourites)
            }
        }
        // Outside the glass and the context menu: both are backed by views
        // that only hit-test within the capsule, so taps on the popup fell
        // through to the page.
        .overlay(alignment: .top) {
            if omnibox.isActive {
                // An overlay is proposed the field's height, which squeezed
                // the popup down to a single row.
                popup
                    .frame(height: popupMaxHeight, alignment: .top)
                    .offset(y: 56)
                    .transition(.opacity)
            }
        }
    }

    private var popup: some View {
        BrowserOmniboxPopupContent()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.separator.opacity(0.4), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .accessibilityIdentifier("browser.omnibox.popup")
    }
}
