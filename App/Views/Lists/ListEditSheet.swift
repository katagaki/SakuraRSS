import SwiftUI

struct ListEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let list: FeedList?

    @State private var name = ""
    @State private var selectedIcon = ListIcon.newspaper.rawValue
    @State private var useDefaultDisplayStyle: Bool = true
    @State private var selectedStyle: FeedDisplayStyle = .inbox
    @State private var selectedFeedIDs: Set<Int64> = []
    @State private var hasInitialized = false
    @FocusState private var isNameFieldFocused: Bool

    private var resolvedDisplayStyle: String? {
        useDefaultDisplayStyle ? nil : selectedStyle.rawValue
    }

    private var isEditing: Bool { list != nil }

    private var nameAlreadyExists: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return feedManager.lists.contains { existing in
            existing.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
            && existing.id != (list?.id ?? -1)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !nameAlreadyExists
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(String(localized: "ListEdit.NamePlaceholder", table: "Lists"), text: $name)
                        .focused($isNameFieldFocused)
                    if nameAlreadyExists {
                        Text(String(localized: "ListEdit.NameExists", table: "Lists"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(String(localized: "ListEdit.Icon", table: "Lists")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(
                            rows: Array(repeating: GridItem(.fixed(44), spacing: 12), count: 4),
                            spacing: 12
                        ) {
                            ForEach(ListIcon.allCases) { icon in
                                Button {
                                    selectedIcon = icon.rawValue
                                } label: {
                                    Image(systemName: icon.rawValue)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            selectedIcon == icon.rawValue
                                                ? AnyShapeStyle(.tint.opacity(0.4))
                                                : AnyShapeStyle(.clear)
                                        )
                                        .clipShape(.rect(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(icon.rawValue)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                    }
                    .listRowInsets(EdgeInsets())
                }

                Section(String(localized: "ListEdit.DisplayStyle", table: "Lists")) {
                    Toggle(String(localized: "ListEdit.DisplayStyle.UseDefault", table: "Lists"),
                           isOn: $useDefaultDisplayStyle)
                    if !useDefaultDisplayStyle {
                        Picker(
                            String(localized: "ListEdit.DisplayStyle", table: "Lists"),
                            selection: $selectedStyle
                        ) {
                            ForEach(FeedDisplayStyle.allCases.filter {
                                $0 != .video && $0 != .podcast
                            }, id: \.self) { style in
                                Text(style.localizedName).tag(style)
                            }
                        }
                    }
                }

                Section(String(localized: "ListEdit.Feeds", table: "Lists")) {
                    if feedManager.feeds.isEmpty {
                        Text(String(localized: "ListEdit.Feeds.Empty", table: "Lists"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(feedManager.feeds) { feed in
                            Button {
                                if selectedFeedIDs.contains(feed.id) {
                                    selectedFeedIDs.remove(feed.id)
                                } else {
                                    selectedFeedIDs.insert(feed.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    FeedIcon(feed: feed, size: 28, cornerRadius: 6)
                                    Text(feed.title)
                                        .font(.body)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedFeedIDs.contains(feed.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing
                             ? String(localized: "ListEdit.Title.Edit", table: "Lists")
                             : String(localized: "ListEdit.Title.New", table: "Lists"))
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
                    .disabled(!canSave)
                }
            }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                if let list {
                    name = list.name
                    selectedIcon = list.icon
                    if let savedStyle = list.displayStyle,
                       let style = FeedDisplayStyle(rawValue: savedStyle) {
                        useDefaultDisplayStyle = false
                        selectedStyle = style
                    } else {
                        useDefaultDisplayStyle = true
                    }
                    selectedFeedIDs = feedManager.feedIDs(for: list)
                } else {
                    isNameFieldFocused = true
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let list {
            feedManager.updateList(list, name: trimmedName, icon: selectedIcon,
                                   displayStyle: resolvedDisplayStyle)
            let currentIDs = feedManager.feedIDs(for: list)
            for id in selectedFeedIDs where !currentIDs.contains(id) {
                if let feed = feedManager.feedsByID[id] {
                    feedManager.addFeedToList(list, feed: feed)
                }
            }
            for id in currentIDs where !selectedFeedIDs.contains(id) {
                if let feed = feedManager.feedsByID[id] {
                    feedManager.removeFeedFromList(list, feed: feed)
                }
            }
        } else {
            if (try? feedManager.createList(name: trimmedName, icon: selectedIcon)) != nil {
                if let newList = feedManager.lists.last {
                    for id in selectedFeedIDs {
                        if let feed = feedManager.feedsByID[id] {
                            feedManager.addFeedToList(newList, feed: feed)
                        }
                    }
                    if let displayStyle = resolvedDisplayStyle {
                        feedManager.updateList(
                            newList,
                            name: trimmedName,
                            icon: selectedIcon,
                            displayStyle: displayStyle
                        )
                    }
                }
            }
        }
        dismiss()
    }
}
