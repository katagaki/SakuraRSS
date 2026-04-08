import SwiftUI

struct FeedRulesSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let feed: Feed

    @State private var allowedKeywords: [String]
    @State private var mutedKeywords: [String]
    @State private var mutedAuthors: [String]
    @State private var allowedKeywordInput: String = ""
    @State private var keywordInput: String = ""
    @State private var authorInput: String = ""
    @State private var availableAuthors: [String] = []
    @FocusState private var isAllowedKeywordFieldFocused: Bool
    @FocusState private var isKeywordFieldFocused: Bool
    @FocusState private var isAuthorFieldFocused: Bool

    init(feed: Feed) {
        self.feed = feed
        _allowedKeywords = State(initialValue: [])
        _mutedKeywords = State(initialValue: [])
        _mutedAuthors = State(initialValue: [])
    }

    var suggestedAuthors: [String] {
        let existing = Set(mutedAuthors)
        return availableAuthors
            .filter { !existing.contains($0) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("FeedRules.AllowedKeywordPlaceholder",
                                  text: $allowedKeywordInput)
                            .frame(maxWidth: .infinity)
                            .focused($isAllowedKeywordFieldFocused)
                            .onSubmit { addAllowedKeyword() }
                        Button("FeedRules.Add") {
                            addAllowedKeyword()
                        }
                        .fixedSize()
                        .disabled(allowedKeywordInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                        dimensions.width
                    }

                    ForEach(allowedKeywords, id: \.self) { keyword in
                        Text(keyword)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                                dimensions.width
                            }
                    }
                    .onDelete { indexSet in
                        allowedKeywords.remove(atOffsets: indexSet)
                    }
                } header: {
                    Text("FeedRules.AllowedKeywords")
                } footer: {
                    Text("FeedRules.AllowedKeywords.Footer")
                }

                Section {
                    HStack {
                        TextField("FeedRules.KeywordPlaceholder",
                                  text: $keywordInput)
                            .frame(maxWidth: .infinity)
                            .focused($isKeywordFieldFocused)
                            .onSubmit { addKeyword() }
                        Button("FeedRules.Add") {
                            addKeyword()
                        }
                        .fixedSize()
                        .disabled(keywordInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                        dimensions.width
                    }

                    ForEach(mutedKeywords, id: \.self) { keyword in
                        Text(keyword)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                                dimensions.width
                            }
                    }
                    .onDelete { indexSet in
                        mutedKeywords.remove(atOffsets: indexSet)
                    }
                } header: {
                    Text("FeedRules.MutedKeywords")
                } footer: {
                    Text("FeedRules.MutedKeywords.Footer")
                }

                Section {
                    HStack {
                        TextField("FeedRules.AuthorPlaceholder",
                                  text: $authorInput)
                            .frame(maxWidth: .infinity)
                            .focused($isAuthorFieldFocused)
                            .onSubmit { addAuthor() }
                        Button("FeedRules.Add") {
                            addAuthor()
                        }
                        .fixedSize()
                        .disabled(authorInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                        dimensions.width
                    }

                    if !suggestedAuthors.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedAuthors, id: \.self) { author in
                                    Button {
                                        mutedAuthors.append(author)
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
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                                dimensions.width
                            }
                    }
                    .onDelete { indexSet in
                        mutedAuthors.remove(atOffsets: indexSet)
                    }
                } header: {
                    Text("FeedRules.MutedAuthors")
                } footer: {
                    Text("FeedRules.MutedAuthors.Footer")
                }
            }
            .navigationTitle("FeedRules.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        save()
                    }
                }
            }
            .onAppear {
                allowedKeywords = feedManager.allowedKeywords(for: feed)
                mutedKeywords = feedManager.mutedKeywords(for: feed)
                mutedAuthors = feedManager.mutedAuthors(for: feed)
                availableAuthors = feedManager.uniqueAuthors(for: feed)
            }
        }
    }

    private func addAllowedKeyword() {
        let trimmed = allowedKeywordInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !allowedKeywords.contains(trimmed) else { return }
        allowedKeywords.append(trimmed)
        allowedKeywordInput = ""
        isAllowedKeywordFieldFocused = true
    }

    private func addKeyword() {
        let trimmed = keywordInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !mutedKeywords.contains(trimmed) else { return }
        mutedKeywords.append(trimmed)
        keywordInput = ""
        isKeywordFieldFocused = true
    }

    private func addAuthor() {
        let trimmed = authorInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !mutedAuthors.contains(trimmed) else { return }
        mutedAuthors.append(trimmed)
        authorInput = ""
        isAuthorFieldFocused = true
    }

    private func save() {
        feedManager.saveAllowedKeywords(allowedKeywords, for: feed)
        feedManager.saveMutedKeywords(mutedKeywords, for: feed)
        feedManager.saveMutedAuthors(mutedAuthors, for: feed)
        dismiss()
    }
}
