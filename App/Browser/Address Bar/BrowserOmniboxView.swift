import EnhancedNavigation
import SwiftUI
import Hanami

/// The editing surface: the dimmed page, the suggestions, and the field
/// itself. The field lives here rather than in the bottom bar because only
/// this overlay is laid out above the keyboard.
struct BrowserOmniboxView: View {

    /// Raised alongside the body-size rows: at the old height the first
    /// section header was already scrolled out of view.
    private static let suggestionListMaxHeight: CGFloat = 420

    /// The glass a `.bottomBar` item draws, read off the rendered view
    /// hierarchy: 48pt on every device and at every content size, since the
    /// bar clamps rather than growing with the text. The field is not a
    /// toolbar item, so nothing else would give it the size of the bar it
    /// stands in for.
    private static let fieldHeight: CGFloat = 48

    @FocusState private var isFieldFocused: Bool

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserOmniboxModel.self) private var omnibox
    @Environment(\.browserAddFeedAction) private var addFeed
    @Environment(\.browserOmniboxSubmit) private var submitOmnibox

    private var suggestions: [BrowserSuggestion] {
        BrowserSuggestionResolver(feedManager: feedManager)
            .suggestions(for: omnibox.text, contentMatches: omnibox.contentMatches)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea([.container, .keyboard])
                .contentShape(.rect)
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // The list only claims the room it needs, so the dimmed page
                // above it stays tappable the way Safari's does.
                Spacer(minLength: 0)
                suggestionList
                    // Bottom aligned: a maxHeight frame centres its content,
                    // which left the rows floating in the middle of the box
                    // with a dead gap above the field.
                    .frame(
                        maxHeight: BrowserOmniboxView.suggestionListMaxHeight,
                        alignment: .bottom
                    )
                fieldBar
            }
        }
        .task(id: omnibox.text) {
            await refreshContentMatches()
        }
    }

    private var fieldBar: some View {
        CompatibleGlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                BrowserOmniboxField(
                    model: omnibox,
                    onSubmit: { submitOmnibox?() },
                    isFocused: $isFieldFocused
                )
                    .frame(maxWidth: .infinity)
                    .frame(height: BrowserOmniboxView.fieldHeight)
                    .compatibleGlassEffect(in: Capsule(), interactive: true)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .medium))
                        // A glass button style pads the label, so the circle
                        // would outgrow the field. Sized here and given the
                        // glass directly, the way the field is.
                        .frame(
                            width: BrowserOmniboxView.fieldHeight,
                            height: BrowserOmniboxView.fieldHeight
                        )
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .compatibleGlassEffect(in: Circle(), interactive: true)
                .accessibilityLabel(String(localized: "AddressField.Cancel", table: "Browser"))
            }
            .padding(.horizontal, 16)
            .browserOmniboxBarInset()
        }
    }

    /// Focus goes first and outside the animation: the keyboard then starts
    /// on its way down as the bar fades, rather than after it.
    private func dismiss() {
        isFieldFocused = false
        withAnimation(BrowserOmniboxModel.transition) {
            omnibox.deactivate()
        }
    }

    private var suggestionList: some View {
        // Hugs its content when it is short, scrolls once it is not. A plain
        // ScrollView always claims its full height, which left a dead gap
        // between the last suggestion and the field.
        ViewThatFits(in: .vertical) {
            suggestionRows
            ScrollView {
                suggestionRows
            }
            .compatibleInteractiveKeyboardDismissal()
            .defaultScrollAnchor(.bottom)
        }
    }

    private var suggestionRows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(BrowserSuggestion.Section.allCases, id: \.rawValue) { section in
                let sectionSuggestions = suggestions.filter { $0.section == section }
                if !sectionSuggestions.isEmpty {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                    ForEach(sectionSuggestions) { suggestion in
                        BrowserSuggestionRow(suggestion: suggestion) {
                            apply(suggestion)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                    }
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func refreshContentMatches() async {
        let query = omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            omnibox.contentMatches = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let found = (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
        guard !Task.isCancelled else { return }
        omnibox.contentMatches = Array(found.prefix(4))
    }

    private func apply(_ suggestion: BrowserSuggestion) {
        switch suggestion.kind {
        case .place(let location):
            store.navigate(to: location)
        case .feed(let feed):
            store.navigate(to: .feed(feed.id))
        case .list(let list):
            store.navigate(to: .list(list.id))
        case .article(let article):
            store.push(article)
        case .searchContent(let query):
            store.navigate(to: .search(query))
        case .discoverFeeds(let host):
            addFeed?("https://\(host)")
        }
        dismiss()
    }
}
