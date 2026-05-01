import SwiftUI

struct EditFeedRulesTab: View {

    @Environment(FeedManager.self) var feedManager
    @Binding var feed: Feed?
    let feedID: Int64

    @State private var allowedKeywords: [String] = []
    @State private var mutedKeywords: [String] = []
    @State private var mutedAuthors: [String] = []
    @State private var allowedKeywordInput: String = ""
    @State private var keywordInput: String = ""
    @State private var authorInput: String = ""
    @State private var availableAuthors: [String] = []
    @State private var hasInitialized: Bool = false
    @FocusState private var isAllowedKeywordFieldFocused: Bool
    @FocusState private var isKeywordFieldFocused: Bool
    @FocusState private var isAuthorFieldFocused: Bool

    var suggestedAuthors: [String] {
        let existing = Set(mutedAuthors)
        return availableAuthors
            .filter { !existing.contains($0) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        Group {
            if feed != nil {
                rulesList
            } else {
                Color.clear
            }
        }
        .onAppear {
            guard let feed else { return }
            if !hasInitialized {
                hasInitialized = true
                allowedKeywords = feedManager.allowedKeywords(for: feed)
                mutedKeywords = feedManager.mutedKeywords(for: feed)
                mutedAuthors = feedManager.mutedAuthors(for: feed)
            }
            if availableAuthors.isEmpty {
                availableAuthors = feedManager.uniqueAuthors(for: feed)
            }
        }
    }

    @ViewBuilder
    private var rulesList: some View {
        Form {
            allowedKeywordsSection
            mutedKeywordsSection
            mutedAuthorsSection
        }
    }

    private var allowedKeywordsSection: some View {
        Section {
            HStack {
                TextField(String(localized: "FeedRules.AllowedKeywordPlaceholder", table: "Feeds"),
                          text: $allowedKeywordInput)
                .frame(maxWidth: .infinity)
                .focused($isAllowedKeywordFieldFocused)
                .onSubmit { addAllowedKeyword() }
                Button(String(localized: "FeedRules.Add", table: "Feeds")) {
                    addAllowedKeyword()
                }
                .fixedSize()
                .disabled(allowedKeywordInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(allowedKeywords, id: \.self) { keyword in
                Text(keyword)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onDelete { indexSet in
                allowedKeywords.remove(atOffsets: indexSet)
                commitAllowedKeywords()
            }
        } header: {
            Text(String(localized: "FeedRules.AllowedKeywords", table: "Feeds"))
        } footer: {
            Text(String(localized: "FeedRules.AllowedKeywords.Footer", table: "Feeds"))
        }
    }

    private var mutedKeywordsSection: some View {
        Section {
            HStack {
                TextField(String(localized: "FeedRules.KeywordPlaceholder", table: "Feeds"),
                          text: $keywordInput)
                .frame(maxWidth: .infinity)
                .focused($isKeywordFieldFocused)
                .onSubmit { addKeyword() }
                Button(String(localized: "FeedRules.Add", table: "Feeds")) {
                    addKeyword()
                }
                .fixedSize()
                .disabled(keywordInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(mutedKeywords, id: \.self) { keyword in
                Text(keyword)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onDelete { indexSet in
                mutedKeywords.remove(atOffsets: indexSet)
                commitMutedKeywords()
            }
        } header: {
            Text(String(localized: "FeedRules.MutedKeywords", table: "Feeds"))
        } footer: {
            Text(String(localized: "FeedRules.MutedKeywords.Footer", table: "Feeds"))
        }
    }

    private var mutedAuthorsSection: some View {
        Section {
            HStack {
                TextField(String(localized: "FeedRules.AuthorPlaceholder", table: "Feeds"),
                          text: $authorInput)
                .frame(maxWidth: .infinity)
                .focused($isAuthorFieldFocused)
                .onSubmit { addAuthor() }
                Button(String(localized: "FeedRules.Add", table: "Feeds")) {
                    addAuthor()
                }
                .fixedSize()
                .disabled(authorInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !suggestedAuthors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedAuthors, id: \.self) { author in
                            Button {
                                mutedAuthors.append(author)
                                commitMutedAuthors()
                            } label: {
                                Text(author)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 18)
                }
                .listRowInsets(.horizontal, 0)
            }

            ForEach(mutedAuthors, id: \.self) { author in
                Text(author)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onDelete { indexSet in
                mutedAuthors.remove(atOffsets: indexSet)
                commitMutedAuthors()
            }
        } header: {
            Text(String(localized: "FeedRules.MutedAuthors", table: "Feeds"))
        } footer: {
            Text(String(localized: "FeedRules.MutedAuthors.Footer", table: "Feeds"))
        }
    }

    private func addAllowedKeyword() {
        let trimmed = allowedKeywordInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !allowedKeywords.contains(trimmed) else { return }
        allowedKeywords.append(trimmed)
        allowedKeywordInput = ""
        isAllowedKeywordFieldFocused = true
        commitAllowedKeywords()
    }

    private func addKeyword() {
        let trimmed = keywordInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !mutedKeywords.contains(trimmed) else { return }
        mutedKeywords.append(trimmed)
        keywordInput = ""
        isKeywordFieldFocused = true
        commitMutedKeywords()
    }

    private func addAuthor() {
        let trimmed = authorInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !mutedAuthors.contains(trimmed) else { return }
        mutedAuthors.append(trimmed)
        authorInput = ""
        isAuthorFieldFocused = true
        commitMutedAuthors()
    }

    private func commitAllowedKeywords() {
        guard let feed else { return }
        feedManager.saveAllowedKeywords(allowedKeywords, for: feed)
    }

    private func commitMutedKeywords() {
        guard let feed else { return }
        feedManager.saveMutedKeywords(mutedKeywords, for: feed)
    }

    private func commitMutedAuthors() {
        guard let feed else { return }
        feedManager.saveMutedAuthors(mutedAuthors, for: feed)
    }
}
