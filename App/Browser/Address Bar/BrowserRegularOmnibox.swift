import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserRegularOmnibox: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(BrowserTabStore.self) var store
    @Environment(BrowserPageSlots.self) private var slots
    @Environment(BrowserFavourites.self) private var favourites
    @Environment(BrowserOmniboxModel.self) var omnibox
    @Environment(\.browserAddFeedAction) var addFeed
    @Environment(\.browserOmniboxAction) private var openOmnibox
    @Environment(\.browserOmniboxSubmit) var submitOmnibox
    @FocusState var isFieldFocused: Bool
    @State var selectedSuggestionID: String?

    let popupMaxHeight: CGFloat

    var suggestions: [BrowserSuggestion] {
        BrowserSuggestionResolver(feedManager: feedManager)
            .suggestions(for: omnibox.text, contentMatches: omnibox.contentMatches)
    }

    private var isQueryEmpty: Bool {
        omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if omnibox.isActive {
                BrowserOmniboxField(model: omnibox, onSubmit: submit, isFocused: $isFieldFocused)
                    .onKeyPress(.escape) {
                        dismiss()
                        return .handled
                    }
                    .onKeyPress(.downArrow) { moveSelection(forward: true) }
                    .onKeyPress(.upArrow) { moveSelection(forward: false) }
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
            if omnibox.isActive, !(isQueryEmpty && feedManager.feeds.isEmpty) {
                // An overlay is proposed the field's height, which squeezed
                // the popup down to a single row.
                popup
                    .frame(height: popupMaxHeight, alignment: .top)
                    .offset(y: 56)
                    .transition(.opacity)
            }
        }
        .onChange(of: omnibox.isActive) {
            if !omnibox.isActive {
                isFieldFocused = false
                selectedSuggestionID = nil
            }
        }
        .onChange(of: omnibox.text) { selectedSuggestionID = nil }
        .task(id: omnibox.text) { await refreshContentMatches() }
    }

    private var popup: some View {
        Group {
            if isQueryEmpty {
                BrowserOmniboxFollowingGrid(
                    openFeed: { feed in open(.feed(feed.id)) },
                    openSection: { section in open(.feedSection(section)) },
                    fitsContent: true
                )
            } else {
                BrowserOmniboxSuggestionList(
                    suggestions: suggestions,
                    selectedSuggestionID: selectedSuggestionID,
                    apply: apply
                )
            }
        }
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
