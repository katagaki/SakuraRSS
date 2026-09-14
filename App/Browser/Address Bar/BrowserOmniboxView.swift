import SwiftUI
import Hanami

/// The expanded address field. One field both searches what is already
/// subscribed and offers to go find feeds at an address that is not.
struct BrowserOmniboxView: View {

    private static let suggestionListMaxHeight: CGFloat = 340

    @Environment(FeedManager.self) private var feedManager
    let store: BrowserTabStore
    @Binding var isPresented: Bool
    @Binding var pendingAddFeedURL: String?

    @State private var text: String = ""
    @State private var contentMatches: [Article] = []
    @FocusState private var isFieldFocused: Bool

    private var suggestions: [BrowserSuggestion] {
        BrowserSuggestionResolver(feedManager: feedManager)
            .suggestions(for: text, contentMatches: contentMatches)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // The list only claims the room it needs, so the dimmed page
                // above it stays tappable the way Safari's does.
                Spacer(minLength: 0)
                suggestionList
                    .frame(maxHeight: BrowserOmniboxView.suggestionListMaxHeight)
                inputRow
            }
        }
        .task {
            isFieldFocused = true
        }
        .task(id: text) {
            await refreshContentMatches()
        }
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(BrowserSuggestion.Section.allCases, id: \.rawValue) { section in
                    let sectionSuggestions = suggestions.filter { $0.section == section }
                    if !sectionSuggestions.isEmpty {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 6)
                        ForEach(sectionSuggestions) { suggestion in
                            BrowserSuggestionRow(suggestion: suggestion) {
                                apply(suggestion)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .compatibleInteractiveKeyboardDismissal()
        .defaultScrollAnchor(.bottom)
    }

    private var inputField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "AddressField.Prompt", table: "Browser"),
                text: $text
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isFieldFocused)
            .onSubmit { submit() }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .compatibleGlassEffect(in: .capsule)
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            inputField
            Button(String(localized: "AddressField.Cancel", table: "Browser")) {
                dismiss()
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func refreshContentMatches() async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            contentMatches = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let found = (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
        guard !Task.isCancelled else { return }
        contentMatches = Array(found.prefix(4))
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let urlString = BrowserAddressInput.normalizedURLString(from: trimmed) {
            pendingAddFeedURL = urlString
        } else {
            store.navigate(to: .search(trimmed))
        }
        dismiss()
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
            pendingAddFeedURL = "https://\(host)"
        }
        dismiss()
    }

    private func dismiss() {
        isFieldFocused = false
        withAnimation(.smooth.speed(2.0)) {
            isPresented = false
        }
    }
}
